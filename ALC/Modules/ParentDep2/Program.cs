namespace ParentDep2;

public static class SomeClass
{
    public static string GetValue()
        => SharedDep.SomeClass.GetValueNew();
}
