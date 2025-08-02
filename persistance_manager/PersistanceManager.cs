using Dgraph;
using Godot;
using Grpc.Net.Client;
using System;
using System.Threading.Tasks;

public partial class PersistanceManager : Node
{
	ConfigFile configFile = new ConfigFile();
	DgraphClient persistanceClient;
	GrpcChannel channel; // Stocker la référence du channel

	bool enabled = false;

	const string SECTION_CONF = "persistance";

	// Called when the node enters the scene tree for the first time.
	public override async void _Ready()
	{
		try
		{
			GD.Print("Start C# Persistent manager");
			configFile.Load("res://server.ini");

			if (configFile.GetValue(SECTION_CONF, "enabled").AsBool())
			{
				enabled = true;

				// This switch must be set before creating the GrpcChannel/HttpClient.
				//AppContext.SetSwitch(
				//	"System.Net.Http.SocketsHttpHandler.Http2UnencryptedSupport", true);

				// Read host from configuration
				var hostStr = configFile.GetValue(SECTION_CONF, "DBHost").AsString();
				GD.Print($"Connecting to: {hostStr}");

				var options = new GrpcChannelOptions
				{
					MaxReceiveMessageSize = 4 * 1024 * 1024, // 4MB
					MaxSendMessageSize = 4 * 1024 * 1024,    // 4MB
				};

				// Create the gRPC channel
				channel = GrpcChannel.ForAddress(hostStr, options);

				// Create the Dgraph client using the channel
				persistanceClient = new DgraphClient(channel);

				// Test de connexion simple d'abord
				await TestConnection();

				if (enabled) // Si la connexion réussit
				{
					await TestFirstSchema();
				}
			}
		}
		catch (Exception ex)
		{
			GD.PrintErr($"An error occurred in _Ready: {ex.Message}");
			GD.PrintErr($"Stack trace: {ex.StackTrace}");
			enabled = false;
		}
	}

	private async Task TestConnection()
	{
		try
		{
			GD.Print("Testing connection to Dgraph...");

			// Test simple de connexion avec une requête basique
			var readOnlyTransaction = persistanceClient.NewReadOnlyTransaction();

			var simpleQuery = @"{
                test(func: has(dgraph.type)) {
                    count(uid)
                }
            }";

			var response = await readOnlyTransaction.Query(simpleQuery);

			if (response.IsSuccess)
			{
				GD.Print("✅ Connection to Dgraph successful!");
			}
			else
			{
				GD.PrintErr($"❌ Connection test failed: {response.Errors[0].Message}");
				enabled = false;
			}
		}
		catch (Exception ex)
		{
			GD.PrintErr($"❌ Connection test exception: {ex.Message}");
			enabled = false;
			throw;
		}
	}

	private async Task TestFirstSchema()
	{
		try
		{
			GD.Print("Applying schema...");

			// 1️⃣ Appliquer un schéma
			var operation = new Api.Operation
			{
				Schema = @"
                    name: string @index(exact) .
                    email: string @index(exact) .  
                    age: int .
                    dgraph.type: [string] @index(exact) .
                "
			};

			var applySchema = await persistanceClient.Alter(operation);
			if (applySchema.IsFailed)
			{
				GD.PrintErr($"Schema application failed: {applySchema.Errors[0].Message}");
				return;
			}
			GD.Print("✅ Schéma appliqué");

			// 2️⃣ Mutation avec gestion d'erreur améliorée
			await PerformTestMutation();

			// 3️⃣ Query pour vérifier les données
			await PerformTestQuery();
		}
		catch (Exception ex)
		{
			GD.PrintErr($"Error in TestFirstSchema: {ex.Message}");
		}
	}

	private async Task PerformTestMutation()
	{
		var transaction = persistanceClient.NewTransaction();

		try
		{
			var mutationJson = @"{
                ""dgraph.type"": ""User"",
                ""name"": ""Alice"",
                ""email"": ""alice@example.com"",
                ""age"": 29
            }";

			GD.Print("Applying mutation...");
			var transactionResponse = await transaction.Mutate(mutationJson);

			if (transactionResponse.IsFailed)
			{
				GD.PrintErr($"Mutation failed: {transactionResponse.Errors[0].Message}");
				return;
			}

			var commitResponse = await transaction.Commit();
			if (commitResponse.IsFailed)
			{
				GD.PrintErr($"Commit failed: {commitResponse.Errors[0].Message}");
				return;
			}

			GD.Print("✅ Mutation committed successfully");
		}
		catch (Exception ex)
		{
			GD.PrintErr($"Exception during mutation: {ex.Message}");
			// Essayer de discard la transaction en cas d'erreur
			if (transaction != null)
			{
				try
				{
					await transaction.Discard();
				}
				catch (Exception discardEx)
				{
					GD.PrintErr($"Error discarding transaction: {discardEx.Message}");
				}
			}
		}
	}

	private async Task PerformTestQuery()
	{
		try
		{
			var readOnlyTransaction = persistanceClient.NewReadOnlyTransaction();

			var query = @"{
                all(func: type(User)) {
                    uid
                    name
                    email
                    age
                }
            }";

			var responseQuery = await readOnlyTransaction.Query(query);
			if (responseQuery.IsFailed)
			{
				GD.PrintErr($"Query failed: {responseQuery.Errors[0].Message}");
				return;
			}

			GD.Print("✅ Query executed successfully");
			GD.Print($"Response JSON: {responseQuery.Value.Json}");
		}
		catch (Exception ex)
		{
			GD.PrintErr($"Exception during query: {ex.Message}");
		}
	}

	public override void _ExitTree()
	{
		// Nettoyer les ressources
		try
		{
			persistanceClient?.Dispose();
			channel?.Dispose();
		}
		catch (Exception ex)
		{
			GD.PrintErr($"Error disposing resources: {ex.Message}");
		}
	}

	// Called every frame. 'delta' is the elapsed time since the previous frame.
	public override void _Process(double delta)
	{
		// Logique de traitement si nécessaire
	}
}