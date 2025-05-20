namespace SharedDep;

public static class SomeClass
{
    public static string GetValue()

        => "Hello Old World!";

#if NEW_VERSION
    public static string GetValueNew()
        => "Hello New World!";
#endif
}
