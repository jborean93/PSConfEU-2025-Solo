namespace SharedDep;

public static class SomeClass
{
    public static string GetOldValue()

        => "Hello Old World!";

#if NEW_VERSION
    public static string GetNewValue()
        => "Hello New World!";
#endif
}
