namespace ParentDep2;

public static class SomeClass
{
    public static string GetOldValue()
        => SharedDep.SomeClass.GetOldValue();

    public static string GetNewValue()
        => SharedDep.SomeClass.GetNewValue();
}
