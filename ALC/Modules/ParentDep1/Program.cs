namespace ParentDep1;

public static class SomeClass
{
    public static string GetValue()
        => SharedDep.SomeClass.GetValue();
}
