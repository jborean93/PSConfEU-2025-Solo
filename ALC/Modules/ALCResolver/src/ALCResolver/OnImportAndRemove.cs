// We only need to configure the ALC for PSv7+.
#if NET8_0_OR_GREATER
using System;
using System.IO;
using System.Management.Automation;
using System.Reflection;
using System.Runtime.Loader;

namespace ALCResolver;

internal class LoadContext : AssemblyLoadContext
{
    private readonly string _assemblyDir;

    public LoadContext(string assemblyDir)
        : base (name: "ALCResolver", isCollectible: false)
    {
        _assemblyDir = assemblyDir;
    }

    protected override Assembly? Load(AssemblyName assemblyName)
    {
        // Adds extra logic to make sure the ALC loads the dll from
        // our bin directory rather than any other dll lookup path.
        string asmPath = Path.Join(_assemblyDir, $"{assemblyName.Name}.dll");
        if (File.Exists(asmPath))
        {
            return LoadFromAssemblyPath(asmPath);
        }
        else
        {
            return null;
        }
    }
}

public class OnModuleImportAndRemove : IModuleAssemblyInitializer, IModuleAssemblyCleanup
{
    private static readonly string _assemblyDir = Path.GetDirectoryName(
        typeof(OnModuleImportAndRemove).Assembly.Location)!;

    private static readonly LoadContext _alc = new LoadContext(_assemblyDir);

    public void OnImport()
    {
        // This is called when the module is imported, we add the
        // resolving event handler to the default ALC to have it resolve
        // ALCResolver.Private into the custom ALC.
        AssemblyLoadContext.Default.Resolving += ResolveAlc;
    }

    public void OnRemove(PSModuleInfo module)
    {
        // When the module is unloaded with Remove-Module this removes the
        // resolving event handler from the default ALC.
        AssemblyLoadContext.Default.Resolving -= ResolveAlc;
    }

    private static Assembly? ResolveAlc(AssemblyLoadContext defaultAlc, AssemblyName assemblyToResolve)
    {
        // Called when the default ALC is unable to resolve an assembly, we check
        // if the assembly is loaded in our bin directory adjacent to this dll
        // and if it is we load it into the custom ALC instead of the default one.
        string asmPath = Path.Join(_assemblyDir, $"{assemblyToResolve.Name}.dll");
        if (IsSatisfyingAssembly(assemblyToResolve, asmPath))
        {
            return _alc.LoadFromAssemblyName(assemblyToResolve);
        }
        else
        {
            return null;
        }
    }

    private static bool IsSatisfyingAssembly(AssemblyName requiredAssemblyName, string assemblyPath)
    {
        // We don't want to load this assembly (ALCResolver) into the custom ALC.
        if (requiredAssemblyName.Name == "ALCResolver" || !File.Exists(assemblyPath))
        {
            return false;
        }

        AssemblyName asmToLoadName = AssemblyName.GetAssemblyName(assemblyPath);

        return string.Equals(asmToLoadName.Name, requiredAssemblyName.Name, StringComparison.OrdinalIgnoreCase)
            && asmToLoadName.Version >= requiredAssemblyName.Version;
    }
}
#endif
