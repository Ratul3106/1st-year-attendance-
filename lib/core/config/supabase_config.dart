class SupabaseConfig {
  // Replace these with your Supabase Project credentials
  static const String supabaseUrl = 'https://your-supabase-project-id.supabase.co';
  static const String supabaseAnonKey = 'your-supabase-anon-key';

  // Automatically enable demo mode when using placeholders
  static bool get isDemoMode =>
      supabaseUrl.contains('your-supabase-project-id') ||
      supabaseAnonKey.contains('your-supabase-anon-key');
}

