using System;
using Tomlyn.Model;

namespace ALCResolver.Private;

internal static class TomlUtil
{
    public static TomlPropertyDisplayKind ParsePropertyDisplayKind(string value)
#if NET8_0_OR_GREATER
        => Enum.Parse<TomlPropertyDisplayKind>(value, true);
#else
        => (TomlPropertyDisplayKind)Enum.Parse(typeof(TomlPropertyDisplayKind), value, true);
#endif
}
