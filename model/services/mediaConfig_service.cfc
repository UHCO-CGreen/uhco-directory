component output="false" singleton {

    variables.publishedSiteBaseUrlKey = "media_published_site_base_url";
    variables.publishedImagesSegment = "_published_images/";

    public any function init() {
        variables.AppConfigService = createObject("component", "cfc.appConfig_service").init();
        return this;
    }

    public string function getPublishedSiteBaseUrl() {
        var configuredBaseUrl = variables.AppConfigService.getValue(
            configKey    = variables.publishedSiteBaseUrlKey,
            defaultValue = ""
        );

        return _normalizeBaseUrl(
            len(trim(configuredBaseUrl)) ? configuredBaseUrl : _getDefaultPublishedSiteBaseUrl()
        );
    }

    public void function setPublishedSiteBaseUrl( required string baseUrl ) {
        var normalized = _normalizeBaseUrl( arguments.baseUrl );

        if ( !reFindNoCase("^https?://", normalized) ) {
            throw(
                type = "MediaConfig.Validation",
                message = "Published site base URL must start with http:// or https://"
            );
        }

        variables.AppConfigService.setValue(
            configKey   = variables.publishedSiteBaseUrlKey,
            configValue = normalized
        );
    }

    public string function getPublishedImageBaseUrl() {
        return getPublishedSiteBaseUrl() & variables.publishedImagesSegment;
    }

    public string function buildPublishedUrl( required string filename ) {
        return getPublishedImageBaseUrl() & trim(arguments.filename);
    }

    public string function normalizePublishedUrl( required string imageUrl ) {
        var normalizedInput = trim(arguments.imageUrl);
        var imagePath = "";

        if ( !len(normalizedInput) ) {
            return "";
        }

        normalizedInput = replace(normalizedInput, "\\", "/", "all");

        if ( left(normalizedInput, 1) EQ "/" ) {
            imagePath = normalizedInput;
        } else {
            var markerPos = findNoCase("/_published_images/", normalizedInput);
            if ( markerPos GT 0 ) {
                imagePath = mid(normalizedInput, markerPos, len(normalizedInput));
            }
        }

        if ( left(imagePath, len("/_published_images/")) EQ "/_published_images/" ) {
            return getPublishedSiteBaseUrl() & mid(imagePath, 2, len(imagePath));
        }

        return normalizedInput;
    }

    public string function buildPublishedFilename(
        required struct user,
        required string variantCode,
        required string extension,
        numeric userImageSourceID = 0
    ) {
        var firstInitial = _sanitizeInitial( arguments.user.FIRSTNAME ?: "" );
        var middleInitial = _sanitizeInitial( arguments.user.MIDDLENAME ?: "" );
        var lastName = _sanitizeSegment( arguments.user.LASTNAME ?: "" );
        var safeVariant = lCase( reReplace(trim(arguments.variantCode), "[^a-zA-Z0-9_\-]", "_", "all") );
        var safeExtension = lCase( trim(arguments.extension) );
        var parts = [];

        if ( safeExtension EQ "jpeg" ) {
            safeExtension = "jpg";
        }

        if ( len(firstInitial) ) {
            arrayAppend(parts, firstInitial);
        }
        if ( len(middleInitial) ) {
            arrayAppend(parts, middleInitial);
        }
        if ( len(lastName) ) {
            arrayAppend(parts, lastName);
        }

        arrayAppend(parts, "u" & val(arguments.user.USERID ?: 0));

        if ( val(arguments.userImageSourceID) GT 0 ) {
            arrayAppend(parts, "src" & val(arguments.userImageSourceID));
        }

        arrayAppend(parts, safeVariant);

        return arrayToList(parts, "_") & "." & safeExtension;
    }

    private string function _normalizeBaseUrl( required string baseUrl ) {
        var normalized = trim(arguments.baseUrl);
        var scheme = "";
        var remainder = "";
        var schemePos = 0;

        if ( !len(normalized) ) {
            normalized = _getDefaultPublishedSiteBaseUrl();
        }

        normalized = replace(normalized, "\\", "/", "all");
        schemePos = find(":", normalized);

        if ( schemePos GT 0 ) {
            scheme = lCase( left(normalized, schemePos - 1) );

            if ( listFindNoCase("http,https", scheme) ) {
                remainder = mid(normalized, schemePos + 1, len(normalized));
                remainder = reReplace(remainder, "^/+", "", "one");
                remainder = reReplace(remainder, "/+", "/", "all");
                normalized = scheme & "://" & remainder;
            }
        }

        if ( reFindNoCase("^https?://", normalized) ) {
            scheme = lCase( listFirst(normalized, ":") );
            remainder = mid(normalized, len(scheme) + 4, len(normalized));
            remainder = reReplace(remainder, "/+", "/", "all");
            normalized = scheme & "://" & remainder;
        }

        if ( right(normalized, 1) NEQ "/" ) {
            normalized &= "/";
        }

        return normalized;
    }

    private string function _getDefaultPublishedSiteBaseUrl() {
        if ( structKeyExists(request, "siteBaseUrl") AND len(trim(request.siteBaseUrl ?: "")) ) {
            return request.siteBaseUrl;
        }

        var scheme = "http";
        var host = trim(cgi.http_host ?: cgi.server_name ?: "127.0.0.1");

        if (
            (structKeyExists(cgi, "https") AND lCase(trim(cgi.https)) EQ "on")
            OR (structKeyExists(cgi, "server_port_secure") AND val(cgi.server_port_secure) EQ 1)
            OR (structKeyExists(cgi, "http_x_forwarded_proto") AND listFirst(cgi.http_x_forwarded_proto, ",") EQ "https")
        ) {
            scheme = "https";
        }

        return scheme & "://" & host;
    }

    private string function _sanitizeInitial( required string rawValue ) {
        var sanitized = _sanitizeSegment( arguments.rawValue );
        return len(sanitized) ? left(sanitized, 1) : "";
    }

    private string function _sanitizeSegment( required string rawValue ) {
        return lCase( reReplace(trim(arguments.rawValue), "[^a-zA-Z0-9]", "", "all") );
    }

}