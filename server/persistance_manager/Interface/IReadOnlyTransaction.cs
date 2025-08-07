using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public interface IReadOnlyTransaction : IDisposable
{
    Task<IOperationResultData> QueryAsync(string query);
}