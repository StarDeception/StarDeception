// Wrapper pour les transactions en lecture seule
using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Godot;

public class DgraphReadOnlyTransactionWrapper : IReadOnlyTransaction
{
    private readonly Dgraph.Transactions.IQuery  _dgraphTransaction;

    public DgraphReadOnlyTransactionWrapper(Dgraph.Transactions.IQuery  dgraphTransaction)
    {
        _dgraphTransaction = dgraphTransaction;
    }

    public async Task<IOperationResult<IQueryResult>> QueryAsync(string query)
    {
        try
        {
            var transaction = _dgraphTransaction;
            var result = await transaction.Query(query);
            
            if (result.IsSuccess)
            {
                var queryResult = new DgraphQueryResult(result.Value.Json);
                return OperationResult<IQueryResult>.Success(queryResult);
            }
            else
            {
                return OperationResult<IQueryResult>.Failure(result.Errors[0].Message);
            }
        }
        catch (Exception ex)
        {   
            return OperationResult<IQueryResult>.Failure(ex.Message, ex);
        }
    }

    public async Task<IOperationResult<T>> QuerySingleAsync<T>(string query) where T : class
    {
        var result = await QueryAsync(query);
        if (!result.IsSuccess)
        {
            return OperationResult<T>.Failure(result.ErrorMessage, result.Exception);
        }

        try
        {
            var entity = result.Data.Deserialize<T>();
            return OperationResult<T>.Success(entity);
        }
        catch (Exception ex)
        {
            return OperationResult<T>.Failure("Deserialization failed", ex);
        }
    }

    public async Task<IOperationResult<List<T>>> QueryListAsync<T>(string query) where T : class
    {
        var result = await QueryAsync(query);
        if (!result.IsSuccess)
        {
            return OperationResult<List<T>>.Failure(result.ErrorMessage, result.Exception);
        }

        try
        {
            var entities = result.Data.DeserializeList<T>();
            return OperationResult<List<T>>.Success(entities);
        }
        catch (Exception ex)
        {
            return OperationResult<List<T>>.Failure("Deserialization failed", ex);
        }
    }

    public void Dispose()
    {
        // Les transactions Dgraph ne semblent pas implémenter IDisposable
    }
}