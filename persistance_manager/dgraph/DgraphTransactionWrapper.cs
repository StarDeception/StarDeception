// Wrapper pour les transactions Dgraph
using System;
using System.Text.Json;
using System.Threading.Tasks;
using Godot;

public class DgraphTransactionWrapper : ITransaction
{
    private readonly Dgraph.Transactions.ITransaction _dgraphTransaction; // Type générique pour éviter la dépendance directe

    public DgraphTransactionWrapper(Dgraph.Transactions.ITransaction dgraphTransaction)
    {
        _dgraphTransaction = dgraphTransaction;
    }

    public async Task<IOperationResult<string>> MutateAsync(string json)
    {
        try
        {
            // Cast vers le type Dgraph réel
            var transaction = _dgraphTransaction;
            var result = await transaction.Mutate(json);
            
            if (result.IsSuccess)
            {
                return OperationResult<string>.Success(json);
            }
            else
            {
                return OperationResult<string>.Failure(result.Errors[0].Message);
            }
        }
        catch (Exception ex)
        {
            return OperationResult<string>.Failure(ex.Message, ex);
        }
    }

    public async Task<IOperationResult<string>> MutateAsync(object entity)
    {
        var json = JsonSerializer.Serialize(entity);
        GD.Print(json);
        return await MutateAsync(json);
    }

    public async Task<IOperationResult> CommitAsync()
    {
        try
        {
            var transaction = _dgraphTransaction ;
            var result = await transaction.Commit();
            
            if (result.IsSuccess)
            {
                return OperationResult.Success();
            }
            else
            {
                return OperationResult.Failure(result.Errors[0].Message);
            }
        }
        catch (Exception ex)
        {
            return OperationResult.Failure(ex.Message, ex);
        }
    }

    public async Task<IOperationResult> DiscardAsync()
    {
        try
        {
            var transaction = _dgraphTransaction;
            await transaction.Discard();
            return OperationResult.Success();
        }
        catch (Exception ex)
        {
            return OperationResult.Failure(ex.Message, ex);
        }
    }

    public void Dispose()
    {
        // Les transactions Dgraph ne semblent pas implémenter IDisposable
        // Mais on peut appeler Discard si nécessaire
    }
}