import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geocoding/geocoding.dart' as geocoding;

const String kGoogleApiKey = 'AIzaSyCjAwFEVV741BblWxJ9esBvD5v2enGhVg4';

class LocationEditScreen extends StatefulWidget {
  final String initialLocation;
  final LatLng? initialCoords;
  const LocationEditScreen({super.key, this.initialLocation = '', this.initialCoords});

  @override
  State<LocationEditScreen> createState() => _LocationEditScreenState();
}

class _LocationEditScreenState extends State<LocationEditScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<dynamic> _suggestions = [];
  Timer? _debounce;
  String? _selectedPlaceId;
  String? _selectedAddress;
  LatLng? _latLng;
  GoogleMapController? _mapController;
  bool _mapMovingMarker = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialLocation;
    if (widget.initialCoords != null) {
      _latLng = widget.initialCoords;
      _updateAddressFromCoords(_latLng!);
    } else if (widget.initialLocation.isNotEmpty) {
      _updateCoordsFromAddress(widget.initialLocation);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!_mapMovingMarker && value.trim().isNotEmpty) {
        await _getSuggestions(value);
      } else {
        setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _getSuggestions(String input) async {
    setState(() => _isLoading = true);
    final url = 'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=${Uri.encodeComponent(input)}&key=$kGoogleApiKey&language=ru&types=address';
    print('[PlacesAPI] GET: $url');
    final resp = await http.get(Uri.parse(url));
    print('[PlacesAPI] Status: ${resp.statusCode}');
    print('[PlacesAPI] body: ${resp.body}');
    if (resp.statusCode == 200) {
      final obj = json.decode(resp.body);
      setState(() {
        _suggestions = obj['predictions'] ?? [];
        _isLoading = false;
      });
      print('[PlacesAPI] suggestions: ${_suggestions.length}');
    } else {
      setState(() { _suggestions = []; _isLoading = false; });
      print('[PlacesAPI][ERROR]');
    }
  }

  Future<void> _selectSuggestion(dynamic suggestion) async {
    _focusNode.unfocus();
    setState(() => _suggestions = []);
    _controller.text = suggestion['description'] ?? '';
    _selectedPlaceId = suggestion['place_id'];
    await _getPlaceDetails(_selectedPlaceId!);
  }

  Future<void> _getPlaceDetails(String placeId) async {
    final detailsUrl = 'https://maps.googleapis.com/maps/api/place/details/json?place_id=$placeId&key=$kGoogleApiKey&language=ru';
    print('[PlaceDetails] GET: $detailsUrl');
    final resp = await http.get(Uri.parse(detailsUrl));
    print('[PlaceDetails] Status: ${resp.statusCode}');
    print('[PlaceDetails] body: ${resp.body}');
    if (resp.statusCode == 200) {
      final details = json.decode(resp.body);
      final loc = details['result']['geometry']['location'];
      setState(() {
        _latLng = LatLng((loc['lat'] * 1.0) ?? 0.0, (loc['lng'] * 1.0) ?? 0.0);
        _selectedAddress = details['result']['formatted_address'];
      });
      _mapController?.moveCamera(CameraUpdate.newLatLng(_latLng!));
    }
  }

  Future<void> _updateAddressFromCoords(LatLng position) async {
    try {
      List<geocoding.Placemark> placemarks = await geocoding.placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          if (place.street != null) place.street,
          if (place.subLocality != null) place.subLocality,
          if (place.locality != null) place.locality,
          if (place.administrativeArea != null) place.administrativeArea,
          if (place.country != null) place.country,
        ].where((e) => e != null && e.toString().trim().isNotEmpty).join(', ');
        setState(() {
          _controller.text = address;
          _selectedAddress = address;
        });
      }
    } catch (_) {}
  }

  Future<void> _updateCoordsFromAddress(String address) async {
    try {
      List<geocoding.Location> locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty) {
        final loc = locations.first;
        final ll = LatLng(loc.latitude, loc.longitude);
        setState(() { _latLng = ll; });
      }
    } catch (_) {}
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> _onMapTap(LatLng position) async {
    setState(() {
      _latLng = position;
      _mapMovingMarker = true;
    });
    await _updateAddressFromCoords(position);
    setState(() { _mapMovingMarker = false; });
  }

  void _close() => Navigator.of(context).pop();
  void _save() {
    Navigator.of(context).pop({
      'address': _controller.text.trim(),
      'lat': _latLng?.latitude,
      'lng': _latLng?.longitude,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A2332),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _close,
        ),
        title: null,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Location',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Поисковое поле
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    style: const TextStyle(color: Colors.white),
                    onChanged: (val) {
                      _onTextChanged(val);
                      if (val.trim().isEmpty) {
                        setState(() {
                          _latLng = null;
                          _selectedAddress = null;
                        });
                      }
                    },
                    decoration: InputDecoration(
                      hintText: 'Enter event location',
                      hintStyle: const TextStyle(color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFF1A2332),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[600]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.blue),
                      ),
                      suffixIcon: _controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Colors.white),
                              onPressed: () {
                                setState(() {
                                  _controller.clear();
                                  _suggestions = [];
                                  _latLng = null;
                                  _selectedAddress = null;
                                });
                              },
                            )
                          : null,
                    ),
                    autofocus: true,
                  ),
                  // Подсказки
                  if (_suggestions.isNotEmpty)
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200),
                      child: Material(
                        elevation: 6,
                        borderRadius: BorderRadius.circular(8),
                        color: const Color(0xFF1A2332),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _suggestions.length,
                          itemBuilder: (ctx, idx) {
                            final s = _suggestions[idx];
                            return ListTile(
                              title: Text(s['description'] ?? '', style: const TextStyle(color: Colors.white)),
                              onTap: () => _selectSuggestion(s),
                            );
                          },
                        ),
                      ),
                    ),
                  // Если есть координаты — карта (но строк с адресом/координатами уже нет)
                  if (_latLng != null)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GoogleMap(
                          key: ValueKey(_latLng),
                          onMapCreated: _onMapCreated,
                          markers: {
                            Marker(
                              markerId: const MarkerId('address'),
                              position: _latLng!,
                              draggable: true,
                              onDragEnd: (newPos) => _onMapTap(newPos),
                            ),
                          },
                          initialCameraPosition: CameraPosition(
                            target: _latLng!,
                            zoom: 15,
                          ),
                          onTap: _onMapTap,
                          myLocationButtonEnabled: false,
                          zoomControlsEnabled: false,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Нижняя кнопка сохраняется всегда
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: const BoxDecoration(
              color: Color(0xFF0F1419),
              boxShadow: [
                BoxShadow(
                  color: Color(0x22000000),
                  blurRadius: 4,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1F2B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Add Location',
                    style: TextStyle(
                      color: Color(0xFF1A1F2B),
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
