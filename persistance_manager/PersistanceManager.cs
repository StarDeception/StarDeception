using FluentResults;
using Godot;
using Pb;
using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Threading.Tasks;

public partial class PersistanceManager : Node
{
    private static IPersistenceProvider _persistenceProvider;
    private ConfigFile _configFile = new ConfigFile();
    private bool _enabled = false;

	const string SECTION_CONF = "persistance";

	// Called when the node enters the scene tree for the first time.
	public override async void _Ready()
	{
        if (_persistenceProvider != null) {
            GD.PrintErr("Client Is already start");
        } else {
            try
            {
                GD.Print("Start Abstracted Persistence Manager");
                _configFile.Load("res://server.ini");

                if (_configFile.GetValue(SECTION_CONF, "enabled").AsBool())
                {
                    _enabled = true;
                    
                    // Créer le provider selon la configuration
                    var dbType = _configFile.GetValue(SECTION_CONF, "type", "dgraph").AsString();
                    var dbHost = _configFile.GetValue(SECTION_CONF, "DBHost").AsString();

                    _persistenceProvider = CreateProvider(dbType, dbHost);

                    if (await _persistenceProvider.InitializeAsync())
                    {
                        GD.Print("✅ Database connection established");
                    }
                    else
                    {
                        GD.PrintErr("❌ Failed to initialize database connection");
                        _enabled = false;
                    }

                    //await RunTests();
                }
            }
            catch (Exception ex)
            {
                GD.PrintErr($"An error occurred in _Ready: {ex.Message}");
                _enabled = false;
            }
        }
		
	}

    public string  SaveObj(string obj)
    {
        var result = SaveAsync(obj).GetAwaiter().GetResult();
        if (result.IsSuccess)
        {
            GD.Print("✅ Save executed successfully");
        }
        else
        {
            GD.PrintErr($"❌ Save failed: {result.ErrorMessage}");
        }
        return result.Uid;
    }

	private IPersistenceProvider CreateProvider(string dbType, string connectionString)
    {
        return dbType.ToLower() switch
        {
            "dgraph" => new DgraphPersistenceProvider(connectionString),
            _ => throw new NotSupportedException($"Database type '{dbType}' is not supported")
        };
    }

    
	public async Task RunTests()
    {
        // Test du schéma
        var schema = @"
            name: string @index(exact) .
            email: string @index(exact) .  
            age: int .
        ";

        if (await _persistenceProvider.ApplySchemaAsync(schema))
        {
            GD.Print("✅ Schema applied successfully");
        }


        var user = new
        {   
            uid = "_:user1",
            //uid  = "0x4e26",
            name = "Alice",
            email = "alice@example.com",
            age = 30,
        };
        
        // Test de mutation
        await TestMutation(user);

        // Test de requête
       // await TestQuery();

        // Test delete
        //await TestDelete(user);
    }   

    private async Task TestMutation(object user)
    {
        using var transaction = await _persistenceProvider.BeginTransactionAsync();
        var json = JsonSerializer.Serialize(user);
        var mutateResult = await transaction.MutateAsync(json);
        GD.Print(mutateResult.Uid);
        if (mutateResult.IsSuccess)
        {
            var commitResult = await transaction.CommitAsync();
            if (commitResult.IsSuccess)
            {
                GD.Print("✅ Mutation and commit successful");
            }
            else
            {
                GD.PrintErr($"❌ Commit failed: {commitResult.ErrorMessage}");
            }
        }
        else
        {
            GD.PrintErr($"❌ Mutation failed: {mutateResult.ErrorMessage}");
        }
    }
/*
        private async Task TestDelete(object user)
    {
        using var transaction = await _persistenceProvider.BeginTransactionAsync();

        var mutateResult = await transaction.DeleteAsync(user);
        if (mutateResult.IsSuccess)
        {
            var commitResult = await transaction.CommitAsync();
            if (commitResult.IsSuccess)
            {
                GD.Print("✅ Delte and commit successful");
            }
            else
            {
                GD.PrintErr($"❌ Commit failed: {commitResult.ErrorMessage}");
            }
        }
        else
        {
            GD.PrintErr($"❌ Delete failed: {mutateResult.ErrorMessage}");
        }
    }

    private async Task TestQuery()
    {
        using var transaction = await _persistenceProvider.BeginReadOnlyTransactionAsync();

        var query = @"{
  all(func: has(name)) {
    uid
    name
    email
    age
    dgraph.type
    dgraph_type
  }
}";

        var result = await transaction.QueryAsync(query);
        if (result.IsSuccess)
        {
            GD.Print("✅ Query executed successfully");
            GD.Print($"Response JSON: {result.Data.Json}");
        }
        else
        {
            GD.PrintErr($"❌ Query failed: {result.ErrorMessage}");
        }
    }
*/
    public override void _ExitTree()
    {
        _persistenceProvider?.Dispose();
    }

    // API publique pour le reste de votre application
    public async Task<IOperationResultData> FindByIdAsync(string id)
    {
        if (!_enabled) return OperationResultData.Failure("Database not enabled");

        using var transaction = await _persistenceProvider.BeginReadOnlyTransactionAsync();
        var query = $"{{ entity(func: uid({id})) {{ expand(_all_) }} }}";
        return await transaction.QueryAsync(query);
    }

    public async Task<IOperationResultData> FindAllAsync(string type)
    {
        if (!_enabled) return OperationResultData.Failure("Database not enabled");

        using var transaction = await _persistenceProvider.BeginReadOnlyTransactionAsync();
        var query = $"{{ all(func: type({type})) {{ expand(_all_) }} }}";
        return await transaction.QueryAsync(query);
    }

    public async Task<OperationResultWithUid> SaveAsync(string entity)
    {       
        if (!_enabled) return OperationResultWithUid.Failure("Database not enabled");

        using var transaction = await _persistenceProvider.BeginTransactionAsync();
        var mutateResult = await transaction.MutateAsync(entity);
        
        var uid = mutateResult.Uid;
        if (mutateResult.IsSuccess)
        {
            var commitResult = await transaction.CommitAsync();
            return commitResult.IsSuccess 
                ? OperationResultWithUid.Success("Entity saved successfully",uid)
                : OperationResultWithUid.Failure(commitResult.ErrorMessage);
        }
        //return OperationResultWithUid.Failure(mutateResult.ErrorMessage);
        return OperationResultWithUid.Failure("Try Async");
    }

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		// Logique de traitement si nécessaire
	}
}