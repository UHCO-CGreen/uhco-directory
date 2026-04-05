component output="false" singleton {

    /**
     * BaseDAO - Provides common database access patterns with retry logic
     * All DAO components should extend this to get automatic retry handling
     * Version: 2 (Updated 2026-04-01 19:40 with column name normalization)
     */

    public any function init() {
        variables.maxRetries = 3;
        variables.retryDelay = 500; // milliseconds
        variables.componentVersion = "2.0_normalized_columns"; // Force recompile
        return this;
    }

    /**
     * Convert a query result to an array of structs with normalized column names
     * Column names are normalized to uppercase for consistency with ColdFusion conventions
     */
    public array function queryToArray( required any qry ) {
        var result = [];
        if (arguments.qry.recordCount == 0) {
            return result;
        }
        
        var columns = listToArray(arguments.qry.columnList);
        var normalizedColumns = []; // Store uppercase versions
        
        // First pass: normalize all column names
        for (var i = 1; i <= arrayLen(columns); i++) {
            arrayAppend(normalizedColumns, uCase(columns[i]));
        }
        
        // Second pass: build result array with normalized column names
        for (var i = 1; i <= arguments.qry.recordCount; i++) {
            var row = {};
            for (var colIndex = 1; colIndex <= arrayLen(columns); colIndex++) {
                var originalCol = columns[colIndex];
                var normalizedCol = normalizedColumns[colIndex];
                // Access the query using the original column name, store with normalized name
                row[normalizedCol] = arguments.qry[originalCol][i];
            }
            arrayAppend(result, row);
        }
        
        return result;
    }

    /**
     * Execute a query with automatic retry logic for transient connection failures
     * 
     * Retries up to maxRetries times on connection-related errors.
     * Uses exponential backoff between attempts.
     * 
     * @sql The SQL query string
     * @params The query parameters (default: empty struct)
     * @options The queryExecute options including datasource, timeout, etc.
     * @returns The query result
     */
    public any function executeQueryWithRetry(
        required string sql,
        struct params = {},
        required struct options
    ) {
        var lastException = "";
        var delay = variables.retryDelay;
        
        for (var attempt = 1; attempt <= variables.maxRetries; attempt++) {
            try {
                return queryExecute(
                    arguments.sql,
                    arguments.params,
                    arguments.options
                );
            } catch (any e) {
                lastException = e;
                
                // Check if this is a connection-related error.
                // ColdFusion puts the generic "Error Executing Database Query" in e.message;
                // the actual JDBC/SQL error text lives in e.detail — check both.
                var sqlState = e.sqlstate ?: "";
                var message  = e.message  ?: "";
                var detail   = e.detail   ?: "";
                
                // SQLSTATE codes for communication errors:
                // 08S01 = Communication link failure
                // 08003 = Connection not open
                // 08006 = Connection failure
                var isConnectionError = (
                    sqlState == "08S01" ||
                    sqlState == "08003" ||
                    sqlState == "08006" ||
                    findNoCase("Connection reset",          message) ||
                    findNoCase("Connection reset",          detail)  ||
                    findNoCase("Communication link failure",message) ||
                    findNoCase("Communication link failure",detail)  ||
                    findNoCase("The connection is broken",  message) ||
                    findNoCase("The connection is broken",  detail)  ||
                    findNoCase("Connection closed",         message) ||
                    findNoCase("Connection closed",         detail)  ||
                    findNoCase("Connection pool",           message) ||
                    findNoCase("Connection pool",           detail)  ||
                    findNoCase("Connection timeout",        message) ||
                    findNoCase("Connection timeout",        detail)
                );
                
                if (isConnectionError && attempt < variables.maxRetries) {
                    // sleep before retrying with exponential backoff
                    sleep(delay);
                    delay = delay * 2; // Double the delay: 500ms, 1000ms, 2000ms
                    continue; // Retry
                } else {
                    // Not a retriable error or max retries reached.
                    // Use rethrow (inside catch) so CF preserves the original exception
                    // type (e.g. "Database") without cfthrow's type-validation restrictions.
                    rethrow;
                }
            }
        }
        
        // Post-loop fallback (all retries exhausted via connection errors).
        // cfthrow rejects CF-internal types like "Database", so sanitize first.
        var safeType = ( isSimpleValue(lastException) || NOT len(lastException.type ?: "") )
            ? "Application"
            : ( listFindNoCase("Database,Expression,Lock,MissingInclude,Template,Object,SearchEngine,Security", lastException.type)
                ? "Application"
                : lastException.type );
        throw(
            type    = safeType,
            message = lastException.message ?: "",
            detail  = lastException.detail  ?: ""
        );
    }

}
