// Wrapper pour les résultats de requête
using System.Collections.Generic;
using System.Text.Json;

public class DgraphQueryResult : IQueryResult
{
    public string Json { get; private set; }

    public DgraphQueryResult(string json)
    {
        Json = json;
    }

    public T Deserialize<T>() where T : class
    {
        return JsonSerializer.Deserialize<T>(Json);
    }

    public List<T> DeserializeList<T>() where T : class
    {
        return JsonSerializer.Deserialize<List<T>>(Json);
    }
}