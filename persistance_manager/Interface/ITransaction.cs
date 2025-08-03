using System;
using System.Threading.Tasks;

public interface ITransaction : IDisposable
{
    Task<IOperationResult<string>> MutateAsync(string json);
    Task<IOperationResult<string>> MutateAsync(object entity);
    Task<IOperationResult> CommitAsync();
    Task<IOperationResult> DiscardAsync();
}