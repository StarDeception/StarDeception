using System;
using System.Threading.Tasks;

public interface ITransaction : IDisposable
{
    Task<IOperationResultWithUid<string>> MutateAsync(string json);
    Task<IOperationResultWithUid<string>> MutateAsync(object entity);

    Task<IOperationResult<string>> DeleteAsync(string json);
    Task<IOperationResult<string>> DeleteAsync(object entity);
    
    Task<IOperationResult> CommitAsync();
    Task<IOperationResult> DiscardAsync();
}