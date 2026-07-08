component output="false" singleton {

    public any function init() {
        variables.searchUrl = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi";
        variables.summaryUrl = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esummary.fcgi";
        return this;
    }

    public struct function fetchForUser(required numeric userID, required struct profile) {
        var searchOptions = _getSearchOptionsFromProfile(arguments.profile);
        var searchQuery = searchOptions.term;
        var searchResponse = {};
        var summaryResponse = {};
        var searchData = {};
        var summaryData = {};
        var ids = [];
        var joinedIDs = "";
        var uid = "";
        var candidates = [];

        if (!len(searchQuery)) {
            return failure(400, "PubMed query is required before fetch.", ["missing PubMed query"]);
        }

        searchResponse = _httpGet(
            variables.searchUrl,
            {
                db = "pubmed",
                term = searchQuery,
                retmode = "json",
                retmax = "200",
                sort = searchOptions.sort
            }
        );

        if (!searchResponse.success) {
            return searchResponse;
        }

        searchData = searchResponse.data;
        ids = _toStringArray(searchData.esearchresult.idlist ?: []);
        if (searchOptions.sortOrder EQ "asc") {
            ids = _reverseArray(ids);
        }
        if (!arrayLen(ids)) {
            return {
                success = true,
                message = "PubMed returned no records.",
                data = {
                    recordsFetched = 0,
                    candidates = []
                }
            };
        }

        joinedIDs = arrayToList(ids);
        summaryResponse = _httpGet(
            variables.summaryUrl,
            {
                db = "pubmed",
                id = joinedIDs,
                retmode = "json"
            }
        );

        if (!summaryResponse.success) {
            return summaryResponse;
        }

        summaryData = summaryResponse.data.result ?: {};
        for (uid in ids) {
            if (structKeyExists(summaryData, uid) AND isStruct(summaryData[uid])) {
                arrayAppend(candidates, normalizeCandidate(summaryData[uid], searchQuery));
            }
        }

        return {
            success = true,
            message = "PubMed records fetched.",
            data = {
                recordsFetched = arrayLen(candidates),
                candidates = candidates
            }
        };
    }

    private struct function normalizeCandidate(required struct record, required string searchQuery) {
        var articleIds = _getArticleIDMap(arguments.record.articleids ?: []);
        var titleText = trim(arguments.record.title ?: "");
        var journalTitle = trim(arguments.record.fulljournalname ?: arguments.record.source ?: "");
        var publicationYear = _extractYear(arguments.record.pubdate ?: arguments.record.epubdate ?: "");
        var sourceURL = "https://pubmed.ncbi.nlm.nih.gov/" & trim(arguments.record.uid ?: "") & "/";
        var authorsText = _joinAuthors(arguments.record.authors ?: []);

        return {
            sourceRecordKey = trim(arguments.record.uid ?: ""),
            sourceTitle = titleText,
            sourceAuthorsText = authorsText,
            sourcePublicationYear = publicationYear,
            sourcePublicationMonth = 0,
            sourceJournalOrSource = journalTitle,
            sourceDOI = trim(articleIds.doi ?: ""),
            sourcePMID = trim(arguments.record.uid ?: articleIds.pubmed ?: ""),
            sourcePMCID = trim(articleIds.pmc ?: articleIds.pmcid ?: ""),
            sourceURL = sourceURL,
            matchConfidence = 0,
            matchStatus = "pending",
            title = titleText,
            authors = authorsText,
            publicationYear = publicationYear,
            journalOrSource = journalTitle,
            doi = trim(articleIds.doi ?: ""),
            pmid = trim(arguments.record.uid ?: articleIds.pubmed ?: ""),
            pmcid = trim(articleIds.pmc ?: articleIds.pmcid ?: ""),
            primaryURL = sourceURL,
            citationText = "",
            rawPayload = {
                query = arguments.searchQuery,
                record = arguments.record
            }
        };
    }

    private struct function _getSearchOptionsFromProfile(required struct profile) {
        var parsedUrl = _parsePubMedUrl(trim(arguments.profile.PROFILEURL ?: ""));
        var queryTerm = trim(arguments.profile.SEARCHQUERY ?: "");
        var browserSort = trim(parsedUrl.sort ?: "");
        var browserSortOrder = lCase(trim(parsedUrl.sort_order ?: "desc"));

        return {
            term = len(trim(parsedUrl.term ?: "")) ? trim(parsedUrl.term) : queryTerm,
            sort = _mapBrowserSortToEutils(browserSort),
            sortOrder = listFindNoCase("asc,desc", browserSortOrder) ? browserSortOrder : "desc"
        };
    }

    private struct function _parsePubMedUrl(required string profileUrl) {
        var result = {};
        var queryString = "";
        var pairs = [];
        var pairValue = "";
        var keyName = "";
        var keyValue = "";
        var queryStart = 0;
        var hashPos = 0;
        var questionDelimiter = chr(63);
        var hashDelimiter = chr(35);
        var pairDelimiter = chr(38);
        var equalsDelimiter = chr(61);

        if (!len(arguments.profileUrl) OR !findNoCase("pubmed.ncbi.nlm.nih.gov", arguments.profileUrl)) {
            return result;
        }

        queryStart = find(questionDelimiter, arguments.profileUrl);
        if (!queryStart) {
            return result;
        }

        queryString = mid(arguments.profileUrl, queryStart + 1, len(arguments.profileUrl));
        hashPos = find(hashDelimiter, queryString);
        if (hashPos) {
            queryString = left(queryString, hashPos - 1);
        }
        if (!len(queryString)) {
            return result;
        }

        pairs = listToArray(queryString, pairDelimiter);
        for (pairValue in pairs) {
            if (listLen(pairValue, equalsDelimiter) GT 1) {
                keyName = lCase(trim(urlDecode(replace(listFirst(pairValue, equalsDelimiter), "+", " ", "all"))));
                keyValue = trim(urlDecode(replace(listRest(pairValue, equalsDelimiter), "+", " ", "all")));
            } else {
                keyName = lCase(trim(urlDecode(replace(pairValue, "+", " ", "all"))));
                keyValue = "";
            }
            if (len(keyName)) {
                result[keyName] = keyValue;
            }
        }

        return result;
    }

    private string function _mapBrowserSortToEutils(string browserSort = "") {
        switch (lCase(trim(arguments.browserSort))) {
            case "date":
            case "pub date":
                return "pub date";
            case "relevance":
                return "relevance";
            case "author":
                return "author";
            default:
                return "pub date";
        }
    }

    private struct function _httpGet(required string baseUrl, required struct params) {
        var queryString = [];
        var keyName = "";
        var finalUrl = arguments.baseUrl;
        var httpResp = {};
        var parsed = {};
        var rawContent = "";

        for (keyName in arguments.params) {
            arrayAppend(queryString, encodeForURL(keyName) & "=" & encodeForURL(toString(arguments.params[keyName] ?: "")));
        }
        if (arrayLen(queryString)) {
            finalUrl &= "?" & arrayToList(queryString, "&");
        }

        cfhttp(url=finalUrl, method="get", timeout="20", result="httpResp") {
            cfhttpparam(type="header", name="Accept", value="application/json");
        }

        if (left(httpResp.statusCode ?: "", 3) NEQ "200") {
            return failure(502, "PubMed request failed with status " & (httpResp.statusCode ?: "Unknown") & ".", []);
        }

        rawContent = trim(toString(httpResp.fileContent ?: ""));

        if (!len(rawContent)) {
            return {
                success = true,
                message = "OK",
                data = {}
            };
        }

        if (left(rawContent, 1) EQ "<") {
            return _parseXmlResponse(rawContent, arguments.baseUrl);
        }

        try {
            parsed = deserializeJSON(rawContent);
        } catch (any e) {
            return failure(502, "PubMed returned unreadable JSON.", [e.message ?: "JSON parse failed"]);
        }

        return {
            success = true,
            message = "OK",
            data = parsed
        };
    }

    private struct function _parseXmlResponse(required string rawContent, required string baseUrl) {
        var xmlDoc = "";
        var idNodes = [];
        var idNode = "";
        var ids = [];
        var countValue = 0;
        var messageText = "";

        try {
            xmlDoc = xmlParse(arguments.rawContent);
        } catch (any e) {
            return failure(502, "PubMed returned unreadable XML.", [e.message ?: "XML parse failed"]);
        }

        if (findNoCase("esearch.fcgi", arguments.baseUrl)) {
            idNodes = xmlSearch(xmlDoc, "/eSearchResult/IdList/Id");
            for (idNode in idNodes) {
                if (len(trim(toString(idNode.xmlText ?: "")))) {
                    arrayAppend(ids, trim(toString(idNode.xmlText)));
                }
            }

            countValue = val(_xmlNodeText(xmlDoc, "/eSearchResult/Count"));
            messageText = _xmlNodeText(xmlDoc, "/eSearchResult/WarningList/OutputMessage");

            return {
                success = true,
                message = len(messageText) ? messageText : "OK",
                data = {
                    esearchresult = {
                        count = countValue,
                        idlist = ids,
                        warningmessage = messageText,
                        querytranslation = _xmlNodeText(xmlDoc, "/eSearchResult/QueryTranslation")
                    }
                }
            };
        }

        return failure(502, "PubMed returned XML instead of JSON for an unsupported endpoint response.", []);
    }

    private string function _xmlNodeText(required any xmlDoc, required string xpath) {
        var nodes = xmlSearch(arguments.xmlDoc, arguments.xpath);
        if (isArray(nodes) AND arrayLen(nodes) GTE 1) {
            return trim(toString(nodes[1].xmlText ?: ""));
        }
        return "";
    }

    private array function _toStringArray(required any items) {
        var result = [];
        var itemValue = "";

        if (!isArray(arguments.items)) {
            return result;
        }

        for (itemValue in arguments.items) {
            if (len(trim(toString(itemValue ?: "")))) {
                arrayAppend(result, trim(toString(itemValue)));
            }
        }

        return result;
    }

    private array function _reverseArray(required array items) {
        var result = [];
        var itemIndex = 0;

        for (itemIndex = arrayLen(arguments.items); itemIndex GTE 1; itemIndex--) {
            arrayAppend(result, arguments.items[itemIndex]);
        }

        return result;
    }

    private struct function _getArticleIDMap(required any articleIds) {
        var result = {};
        var row = {};
        var idType = "";
        var idValue = "";

        if (!isArray(arguments.articleIds)) {
            return result;
        }

        for (row in arguments.articleIds) {
            if (!isStruct(row)) {
                continue;
            }
            idType = lCase(trim(toString(row.idtype ?: "")));
            idValue = trim(toString(row.value ?: ""));
            if (len(idType) AND len(idValue)) {
                result[idType] = idValue;
            }
        }

        return result;
    }

    private numeric function _extractYear(any rawDate = "") {
        var matchValue = reFind("(19|20)\d{2}", toString(arguments.rawDate ?: ""), 1, true);
        if (isStruct(matchValue) AND arrayLen(matchValue.len) GTE 1 AND matchValue.len[1] GT 0) {
            return val(mid(toString(arguments.rawDate ?: ""), matchValue.pos[1], matchValue.len[1]));
        }
        return 0;
    }

    private string function _joinAuthors(any authors = []) {
        var names = [];
        var row = {};
        var authorName = "";

        if (!isArray(arguments.authors)) {
            return "";
        }

        for (row in arguments.authors) {
            if (isStruct(row)) {
                authorName = trim(toString(row.name ?: row.authtype ?: ""));
                if (len(authorName)) {
                    arrayAppend(names, authorName);
                }
            }
        }

        return arrayToList(names, ", ");
    }

    private struct function failure(required numeric statusCode, required string message, array errors = []) {
        return {
            success = false,
            statusCode = arguments.statusCode,
            message = arguments.message,
            errors = arguments.errors,
            data = {}
        };
    }

}