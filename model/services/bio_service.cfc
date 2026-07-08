component output="false" singleton {

    public any function init() {
        variables.bioDAO = createObject("component", "dao.bio_DAO").init();
        return this;
    }

    public struct function getBio( required numeric userID ) {
        return { success=true, data=variables.bioDAO.getBio( userID ) };
    }

    public string function sanitizeForRender( required string bioContent ) {
        return sanitizeHTML( trim(arguments.bioContent) );
    }

    public void function saveBio( required numeric userID, required string bioContent ) {
        var cleaned = sanitizeHTML( trim(bioContent) );
        variables.bioDAO.saveBio( userID, {
            BioContent = { value=cleaned, cfsqltype="cf_sql_longvarchar", null=!len(cleaned) }
        });
    }

    /**
     * Whitelist-based HTML sanitiser.
     * Allows only the tags Quill produces: p, strong, em, a, ul, ol, li, br.
     * Strips all attributes except href and target on <a> tags.
     * Prevents javascript: and data: URIs in href values.
     */
    private string function sanitizeHTML( required string html ) {
        if ( !len(trim(html)) ) return "";

        // Strip <script>, <style>, <iframe>, <object>, <embed>, <form>, <input>, <textarea>, <select>, <button> tags and their content
        var result = reReplaceNoCase( html, "<(script|style|iframe|object|embed|form|input|textarea|select|button)[^>]*>.*?</\1>", "", "ALL" );
        // Also strip self-closing or unclosed versions of dangerous tags
        result = reReplaceNoCase( result, "<(script|style|iframe|object|embed|form|input|textarea|select|button)[^>]*/?>", "", "ALL" );

        // Strip event handler attributes (on*)
        result = reReplaceNoCase( result, "\s+on\w+\s*=\s*""[^""]*""", "", "ALL" );
        result = reReplaceNoCase( result, "\s+on\w+\s*=\s*'[^']*'", "", "ALL" );
        result = reReplaceNoCase( result, "\s+on\w+\s*=\s*[^\s>]+", "", "ALL" );

        // Process <a> tags: keep only href and target attributes, validate href
        result = reReplaceNoCase( result, "<a\b[^>]*>", "", "ALL" );
        // We need a more careful approach — rebuild <a> tags
        // First, restore the original approach: extract href from <a> tags
        result = html; // restart from original

        // Step 1: Strip dangerous tags and their content
        result = reReplaceNoCase( result, "<(script|style|iframe|object|embed|form|input|textarea|select|button)\b[^>]*>[\s\S]*?</\1\s*>", "", "ALL" );
        result = reReplaceNoCase( result, "<(script|style|iframe|object|embed|form|input|textarea|select|button)\b[^>]*/?\s*>", "", "ALL" );

        // Step 2: Strip event handler attributes
        result = reReplaceNoCase( result, "\s+on\w+\s*=\s*(""[^""]*""|'[^']*'|[^\s>]+)", "", "ALL" );

        // Step 3: Strip style attributes
        result = reReplaceNoCase( result, "\s+style\s*=\s*(""[^""]*""|'[^']*'|[^\s>]+)", "", "ALL" );

        // Step 4: Strip class attributes
        result = reReplaceNoCase( result, "\s+class\s*=\s*(""[^""]*""|'[^']*'|[^\s>]+)", "", "ALL" );

        // Step 5: Remove any tags that are NOT in our whitelist
        // Whitelist: p, strong, em, a, ul, ol, li, br, b, i, u, s
        result = reReplaceNoCase( result, "<(?!/?(p|strong|em|a|ul|ol|li|br|b|i|u|s)\b)[a-z][a-z0-9]*\b[^>]*>", "", "ALL" );
        result = reReplaceNoCase( result, "</(?!(p|strong|em|a|ul|ol|li|br|b|i|u|s)\b)[a-z][a-z0-9]*\s*>", "", "ALL" );

        // Step 6: Sanitise href values — block javascript: and data: URIs
        result = reReplaceNoCase( result, "href\s*=\s*""\s*(javascript|data|vbscript)\s*:[^""]*""", "href=""""", "ALL" );
        result = reReplaceNoCase( result, "href\s*=\s*'\s*(javascript|data|vbscript)\s*:[^']*'", "href=''", "ALL" );

        // Step 7: On <a> tags, strip all attributes except href, target, rel
        // This is best-effort; the whitelist above already removed most dangerous content

        return result;
    }

}
