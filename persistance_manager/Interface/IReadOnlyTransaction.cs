using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public interface IReadOnlyTransaction : IDisposable
{
    Task<IOperationResult<IQueryResult>> QueryAsync(string query);
    Task<IOperationResult<T>> QuerySingleAsync<T>(string query) where T : class;
    Task<IOperationResult<List<T>>> QueryListAsync<T>(string query) where T : class;
}