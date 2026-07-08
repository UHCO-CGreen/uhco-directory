component output="false" singleton {

    public any function init() {
        variables.dao = createObject("component", "dao.nameResolution_DAO").init();
        return this;
    }

    public void function resolveRows( required array rows, string userIDKey = "USERID" ) {
        var ids = [];

        for ( var row in arguments.rows ) {
            if ( isStruct(row) AND structKeyExists(row, arguments.userIDKey) AND isNumeric(row[arguments.userIDKey]) ) {
                arrayAppend(ids, val(row[arguments.userIDKey]));
            }
        }

        var aliasMap = _getAliasMapInChunks(ids, 900);

        for ( var rowIndex = 1; rowIndex <= arrayLen(arguments.rows); rowIndex++ ) {
            resolveRow(arguments.rows[rowIndex], aliasMap, arguments.userIDKey);
        }
    }

    public void function attachPrimaryNameEnvelopeToRows(
        required array rows,
        string userIDKey = "USERID",
        boolean overwriteFullName = true
    ) {
        var ids = [];

        for ( var row in arguments.rows ) {
            if ( isStruct(row) AND structKeyExists(row, arguments.userIDKey) AND isNumeric(row[arguments.userIDKey]) ) {
                arrayAppend(ids, val(row[arguments.userIDKey]));
            }
        }

        var aliasMap = _getAliasMapInChunks(ids, 900);

        for ( var i = 1; i <= arrayLen(arguments.rows); i++ ) {
            attachPrimaryNameEnvelopeToRow(
                arguments.rows[i],
                aliasMap,
                arguments.userIDKey,
                arguments.overwriteFullName
            );
        }
    }

    public void function attachPrimaryNameEnvelopeToRow(
        required struct row,
        struct aliasMap = {},
        string userIDKey = "USERID",
        boolean overwriteFullName = true
    ) {
        var first = _cleanPart(arguments.row["FIRSTNAME"] ?: "");
        var middle = _cleanPart(arguments.row["MIDDLENAME"] ?: "");
        var last = _cleanPart(arguments.row["LASTNAME"] ?: "");
        var aliasID = 0;

        if ( structKeyExists(arguments.row, arguments.userIDKey) AND isNumeric(arguments.row[arguments.userIDKey]) ) {
            var aliasKey = toString(val(arguments.row[arguments.userIDKey]));
            if ( structKeyExists(arguments.aliasMap, aliasKey) ) {
                var aliasRow = arguments.aliasMap[aliasKey];
                first = _cleanPart(aliasRow.FIRSTNAME ?: "");
                middle = _cleanPart(aliasRow.MIDDLENAME ?: "");
                last = _cleanPart(aliasRow.LASTNAME ?: "");
                aliasID = val(aliasRow.ALIASID ?: 0);
            }
        }

        arguments.row["FIRSTNAME"] = first;
        arguments.row["MIDDLENAME"] = middle;
        arguments.row["LASTNAME"] = last;
        var full = _buildFullName(first, middle, last);

        if ( arguments.overwriteFullName OR !structKeyExists(arguments.row, "FULLNAME") OR !len(trim(arguments.row["FULLNAME"] ?: "")) ) {
            arguments.row["FULLNAME"] = full;
        }

        arguments.row["NAMES"] = [
            {
                ALIASID = aliasID,
                FIRST = first,
                MIDDLE = middle,
                LAST = last,
                FULL = full,
                PRIMARY = true
            }
        ];
    }

    public array function getAllActiveAliasNameEnvelopeForUser( required numeric userID ) {
        var aliasMap = variables.dao.getAllActiveAliasesByUserMap([arguments.userID]);
        var key = toString(val(arguments.userID));

        if ( structKeyExists(aliasMap, key) ) {
            return aliasMap[key];
        }

        return [];
    }

    private struct function _getAliasMapInChunks( required array ids, numeric chunkSize = 900 ) {
        var merged = {};
        var total = arrayLen(arguments.ids);

        if ( total EQ 0 ) {
            return merged;
        }

        var size = arguments.chunkSize;
        if ( !isNumeric(size) OR size LTE 0 ) {
            size = 900;
        }

        var startIndex = 1;
        while ( startIndex LTE total ) {
            var stopIndex = startIndex + size - 1;
            if ( stopIndex GT total ) {
                stopIndex = total;
            }

            var chunk = [];
            for ( var i = startIndex; i LTE stopIndex; i++ ) {
                arrayAppend(chunk, arguments.ids[i]);
            }

            var partial = variables.dao.getPreferredAliasNameMap(chunk);
            structAppend(merged, partial, true);

            startIndex = stopIndex + 1;
        }

        return merged;
    }

    public void function resolveRow(
        required struct row,
        struct aliasMap = {},
        string userIDKey = "USERID"
    ) {
        var baseFirst = _cleanPart(arguments.row["FIRSTNAME"] ?: "");
        var baseMiddle = _cleanPart(arguments.row["MIDDLENAME"] ?: "");
        var baseLast = _cleanPart(arguments.row["LASTNAME"] ?: "");
        var resolvedFirst = baseFirst;
        var resolvedMiddle = baseMiddle;
        var resolvedLast = baseLast;

        if ( structKeyExists(arguments.row, arguments.userIDKey) AND isNumeric(arguments.row[arguments.userIDKey]) ) {
            var aliasKey = toString(val(arguments.row[arguments.userIDKey]));
            if ( structKeyExists(arguments.aliasMap, aliasKey) ) {
                var aliasRow = arguments.aliasMap[aliasKey];
                resolvedFirst = _cleanPart(aliasRow.FIRSTNAME ?: "");
                resolvedMiddle = _cleanPart(aliasRow.MIDDLENAME ?: "");
                resolvedLast = _cleanPart(aliasRow.LASTNAME ?: "");
            }
        }

        arguments.row["FIRSTNAME"] = resolvedFirst;
        arguments.row["MIDDLENAME"] = resolvedMiddle;
        arguments.row["LASTNAME"] = resolvedLast;
        arguments.row["FULLNAME"] = _buildFullName(resolvedFirst, resolvedMiddle, resolvedLast);
    }

    private string function _cleanPart( any rawValue = "" ) {
        var cleaned = trim(rawValue ?: "");
        if ( !len(cleaned) ) {
            return "";
        }

        if ( reFind("[a-zA-Z0-9]", cleaned) EQ 0 ) {
            return "";
        }

        return cleaned;
    }

    private string function _buildFullName( string first = "", string middle = "", string last = "" ) {
        var parts = [];

        if ( len(trim(arguments.first)) ) {
            arrayAppend(parts, trim(arguments.first));
        }
        if ( len(trim(arguments.middle)) ) {
            arrayAppend(parts, trim(arguments.middle));
        }
        if ( len(trim(arguments.last)) ) {
            arrayAppend(parts, trim(arguments.last));
        }

        return arrayToList(parts, " ");
    }

    /**
     * Strips flat name (and optionally contact) fields from a struct or array of structs.
     * Call after attaching the NAMES envelope to eliminate duplicate/legacy top-level keys.
     *
     * nameFields always stripped: FIRSTNAME, MIDDLENAME, LASTNAME, FULLNAME
     * contactFields stripped when includeContactFields=true: PREFERREDNAME, MAIDENNAME, EMAILPRIMARY
     */
    public void function stripFlatNameFields( required any target, boolean includeContactFields = false ) {
        var toStrip = ["FIRSTNAME", "MIDDLENAME", "LASTNAME", "FULLNAME"];

        if ( arguments.includeContactFields ) {
            arrayAppend(toStrip, "PREFERREDNAME");
            arrayAppend(toStrip, "MAIDENNAME");
            arrayAppend(toStrip, "EMAILPRIMARY");
        }

        if ( isArray(arguments.target) ) {
            for ( var row in arguments.target ) {
                if ( isStruct(row) ) {
                    for ( var key in toStrip ) {
                        structDelete(row, key);
                    }
                }
            }
        } else if ( isStruct(arguments.target) ) {
            for ( var key in toStrip ) {
                structDelete(arguments.target, key);
            }
        }
    }
}
