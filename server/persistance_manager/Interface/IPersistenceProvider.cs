using System.Threading.Tasks;

public interface IPersistenceProvider
{
    Task<bool> InitializeAsync();
    Task<ITransaction> BeginTransactionAsync();
    Task<IReadOnlyTransaction> BeginReadOnlyTransactionAsync();
    Task<bool> ApplySchemaAsync(string schema);
    Task<bool> TestConnectionAsync();
    void Dispose();
}