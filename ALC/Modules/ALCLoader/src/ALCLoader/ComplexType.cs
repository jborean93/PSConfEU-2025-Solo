using System;
using System.Management.Automation;
using Tomlyn.Model;

namespace ALCLoader;

public sealed class ComplexType
{
    public TomlPropertyDisplayKind PropertyDisplayKind { get; set; } = default;
}

[Cmdlet(VerbsCommon.Get, "ComplexType")]
[OutputType(typeof(ComplexType))]
public sealed class GetComplextTypeCommand : PSCmdlet
{
    protected override void EndProcessing()
    {
        WriteObject(new ComplexType() { PropertyDisplayKind = TomlPropertyDisplayKind.InlineTable });
    }
}

[Cmdlet(VerbsCommon.Set, "ComplexType")]
public sealed class SetComplextTypeCommand : PSCmdlet
{
    [Parameter(
        Mandatory = true,
        Position = 0,
        ValueFromPipeline = true
    )]
    public ComplexType[] InputObject { get; set; } = Array.Empty<ComplexType>();

    [Parameter(
        Mandatory = true
    )]
    public string Value { get; set; } = "";

    protected override void ProcessRecord()
    {
        foreach (var item in InputObject)
        {
            // Process each item in the input object
            // For example, you can modify the item here
            item.PropertyDisplayKind = (TomlPropertyDisplayKind)Enum.Parse(typeof(TomlPropertyDisplayKind), Value, true);
        }
    }
}
