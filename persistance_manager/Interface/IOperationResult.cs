using System;
using System.Collections.Generic;
using System.Linq;

public interface IOperationResult
{
    bool IsSuccess { get; }
    
    string ErrorMessage { get; }
    Exception Exception { get; }
}

public interface IOperationResult<T> : IOperationResult
{
    T Data { get; }
}

public interface IOperationResultWithUid<T> : IOperationResult<T>
{
    string Uid { get; } 
}

public class OperationResult : IOperationResult
{
    public bool IsSuccess { get; set; }
    public string ErrorMessage { get; set; }
    public Exception Exception { get; set; }

    public static OperationResult Success() => new OperationResult { IsSuccess = true };
    public static OperationResult Failure(string error, Exception ex = null) => 
        new OperationResult { IsSuccess = false, ErrorMessage = error, Exception = ex };
}

public class OperationResult<T> : OperationResult, IOperationResult<T>
{
    public T Data { get; set; }

    public static OperationResult<T> Success(T data) => 
        new OperationResult<T> { IsSuccess = true, Data = data };
    
    public static new OperationResult<T> Failure(string error, Exception ex = null) => 
        new OperationResult<T> { IsSuccess = false, ErrorMessage = error, Exception = ex };
}


public class OperationResultWithUid<U> : OperationResult<U>, IOperationResultWithUid<U>
{
    public string Uid { get; set; }
    
    // Pour les mutations multiples, Dgraph peut retourner plusieurs UIDs
    public Dictionary<string, string> Uids { get; set; }

    public static OperationResultWithUid<U> Success(U data, string uid) =>
        new OperationResultWithUid<U> { IsSuccess = true, Data = data, Uid = uid };
        
    // Pour les mutations multiples avec plusieurs UIDs
    public static OperationResultWithUid<U> Success(U data, Dictionary<string, string> uids) =>
        new OperationResultWithUid<U> { IsSuccess = true, Data = data, Uids = uids, Uid = uids.First().Value };

    public static OperationResultWithUid<U> Failure(string error, Exception ex = null) =>
        new OperationResultWithUid<U> { IsSuccess = false, ErrorMessage = error, Exception = ex };
        
    public static OperationResultWithUid<U> Failure(string error, string uid, Exception ex = null) =>
        new OperationResultWithUid<U> { IsSuccess = false, ErrorMessage = error, Uid = uid, Exception = ex };
}