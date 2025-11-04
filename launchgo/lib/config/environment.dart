enum Environment { stage, prod }

class EnvironmentConfig {
  static late Environment _environment;
  static late String _baseUrl;
  static late String _streamChatApiKey;

  static void init() {
    // Read environment from compile-time constant
    // Default to stage if not specified
    const String env = String.fromEnvironment('ENV', defaultValue: 'stage');
    
    switch (env) {
      case 'prod':
        _environment = Environment.prod;
        _baseUrl = 'https://api.launchgo.com/api/v1';
        _streamChatApiKey = 'd8v7pmnkuxe8';
        break;
      case 'stage':
      default:
        _environment = Environment.stage;
        _baseUrl = 'https://dev-api.launchgo.com/api/v1';
        _streamChatApiKey = 'b2xg2crxdpft';
        break;
    }
  }

  static Environment get environment => _environment;
  static String get baseUrl => _baseUrl;
  static String get streamChatApiKey => _streamChatApiKey;
  
  static bool get isStage => _environment == Environment.stage;
  static bool get isProd => _environment == Environment.prod;
  
  static String get environmentName => _environment == Environment.prod ? 'Prod' : 'Stage';
}