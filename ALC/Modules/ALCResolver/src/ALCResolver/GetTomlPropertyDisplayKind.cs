using ALCResolver.Private;
using System;
using System.Management.Automation;

namespace ALCResolver;

[Cmdlet(VerbsCommon.Get, "TomlPropertyDisplayKind")]
[OutputType(typeof(Enum))]
public sealed class GetTomlPropertyDisplayKindCommand : PSCmdlet
{
    [Parameter(
        Mandatory = true,
        Position = 0
    )]
    public string Value { get; set; } = "";

    protected override void EndProcessing()
    {
        var res = TomlUtil.ParsePropertyDisplayKind(Value);
        WriteObject(res);
    }
}