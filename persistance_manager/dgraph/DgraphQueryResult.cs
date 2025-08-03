// Wrapper pour les résultats de requête
using System.Collections.Generic;
using System.Text.Json;

public class DgraphQueryResult : IQueryResult
{
    public string Json { get; private set; }
}