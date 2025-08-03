using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class PersistanceManager : Node
{
    private IPersistenceProvider _persistenceProvider;
    private ConfigFile _configFile = new ConfigFile();
    private bool _enabled = false;

	const string SECTION_CONF = "persistance";

	// Called when the node enters the scene tree for the first time.
	public override async void _Ready()
	{
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
                    await RunTests();
                }
                else
                {
                    GD.PrintErr("❌ Failed to initialize database connection");
                    _enabled = false;
                }
            }
        }
        catch (Exception ex)
        {
            GD.PrintErr($"An error occurred in _Ready: {ex.Message}");
            _enabled = false;
        }
	}

	private IPersistenceProvider CreateProvider(string dbType, string connectionString)
    {
        return dbType.ToLower() switch
        {
            "dgraph" => new DgraphPersistenceProvider(connectionString),
            _ => throw new NotSupportedException($"Database type '{dbType}' is not supported")
        };
    }
	    private async Task RunTests()
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
        await TestQuery();

        // Test delete
        await TestDelete(user);
    }   

    private async Task TestMutation(object user)
    {
        using var transaction = await _persistenceProvider.BeginTransactionAsync();

        var mutateResult = await transaction.MutateAsync(user);
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

    public override void _ExitTree()
    {
        _persistenceProvider?.Dispose();
    }

    // API publique pour le reste de votre application
    public async Task<IOperationResult<T>> FindByIdAsync<T>(string id) where T : class
    {
        if (!_enabled) return OperationResult<T>.Failure("Database not enabled");

        using var transaction = await _persistenceProvider.BeginReadOnlyTransactionAsync();
        var query = $"{{ entity(func: uid({id})) {{ expand(_all_) }} }}";
        return await transaction.QuerySingleAsync<T>(query);
    }

    public async Task<IOperationResult<List<T>>> FindAllAsync<T>(string type) where T : class
    {
        if (!_enabled) return OperationResult<List<T>>.Failure("Database not enabled");

        using var transaction = await _persistenceProvider.BeginReadOnlyTransactionAsync();
        var query = $"{{ all(func: type({type})) {{ expand(_all_) }} }}";
        return await transaction.QueryListAsync<T>(query);
    }

    public async Task<IOperationResult<string>> SaveAsync<T>(T entity) where T : class
    {
        if (!_enabled) return OperationResult<string>.Failure("Database not enabled");

        using var transaction = await _persistenceProvider.BeginTransactionAsync();
        var mutateResult = await transaction.MutateAsync(entity);
        
        if (mutateResult.IsSuccess)
        {
            var commitResult = await transaction.CommitAsync();
            return commitResult.IsSuccess 
                ? OperationResult<string>.Success("Entity saved successfully")
                : OperationResult<string>.Failure(commitResult.ErrorMessage);
        }

        return OperationResult<string>.Failure(mutateResult.ErrorMessage);
    }

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		// Logique de traitement si nécessaire
	}
}