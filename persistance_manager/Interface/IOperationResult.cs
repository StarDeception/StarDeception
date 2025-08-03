using System;

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