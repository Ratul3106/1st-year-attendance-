class SupabaseConfig {
  // Configured with the live Supabase Project credentials
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pagucnchqohxvceovpaf.supabase.co',
  );

  // Client-safe public publishable/anonymous API key
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_5-nMq0gB07w5bo2cS-67Vg_IKVQY7_r',
  );

  // Automatically enable demo mode ONLY when placeholders or empty values are present
  static bool get isDemoMode =>
      supabaseUrl.isEmpty ||
      supabaseAnonKey.isEmpty ||
      supabaseUrl.contains('your-supabase-project-id') ||
      supabaseAnonKey.contains('your-supabase-anon-key');
}
