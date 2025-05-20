using System;
using System.Management.Automation;
using Tomlyn.Model;

namespace ALCLoader;

[Cmdlet(VerbsCommon.Get, "TomlPropertyDisplayKind")]
[OutputType(typeof(GetTomlPropertyDisplayKindCommand))]
public sealed class GetTomlPropertyDisplayKindCommand : PSCmdlet
{
    [Parameter(
        Mandatory = true,
        Position = 0
    )]
    public string Value { get; set; } = "";

    protected override void EndProcessing()
    {
#if NET8_0_OR_GREATER
        TomlPropertyDisplayKind res = Enum.Parse<TomlPropertyDisplayKind>(Value, true);
#else
        TomlPropertyDisplayKind res = (TomlPropertyDisplayKind)Enum.Parse(typeof(TomlPropertyDisplayKind), Value, true);
#endif
        WriteObject(res);
    }
}
