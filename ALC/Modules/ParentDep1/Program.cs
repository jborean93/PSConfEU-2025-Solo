namespace ParentDep1;

public static class SomeClass
{
    public static string GetOldValue()
        => SharedDep.SomeClass.GetOldValue();
}
