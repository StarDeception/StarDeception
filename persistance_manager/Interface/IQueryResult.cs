using System.Collections.Generic;

public interface IQueryResult
{
    string Json { get; }
    T Deserialize<T>() where T : class;
    List<T> DeserializeList<T>() where T : class;
}