/// FNV-1a 32bit hash algorithm optimized for Dart Strings
int fastHash(String input) {
  const int prime = 0x01000193; // 16777619
  int hash = 0x811c9dc5; // 2166136261

  for (int i = 0; i < input.length; i++) {
    hash ^= input.codeUnitAt(i);
    hash *= prime;
    hash &= 0xFFFFFFFF; // Ensure it stays a 32-bit number
  }

  // Sign-extend to 32-bit signed integer
  if ((hash & 0x80000000) != 0) {
    hash = hash - 0x100000000;
  }

  return hash;
}
