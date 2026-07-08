component output="false" singleton {

    public any function init() {
        variables.dao = createObject("component", "dao.roster_DAO").init();
        variables.nameResolutionService = createObject("component", "cfc.nameResolution_service").init();
        return this;
    }

    public array function getProgramOptions() {
        return [
            { value = "OD Program", label = "OD Program" },
            { value = "MS Program", label = "MS Program" },
            { value = "PhD Program", label = "PhD Program" }
        ];
    }

    public array function getAvailableGradYears() {
        var rows = variables.dao.getAvailableGradYears();
        var years = [];

        for (var row in rows) {
            arrayAppend(years, val(row.CURRENTGRADYEAR));
        }

        return years;
    }

    public array function getRosterUsers( required numeric gradYear, required string programName ) {
        _validateProgram(arguments.programName);

        var rows = variables.dao.getRosterUsers(arguments.gradYear, arguments.programName);
        variables.nameResolutionService.resolveRows(rows);

        for (var i = 1; i <= arrayLen(rows); i++) {
            rows[i]["FULLNAME"] = _buildFullName(rows[i]);
            rows[i]["IMAGEURL"] = _resolveImageURL(rows[i]);
        }

        return rows;
    }

    public struct function getLayoutConfig( numeric expectedUserCount = 0 ) {
        var pageWidthIn = 11.0;
        var pageHeightIn = 8.5;
        var marginTopIn = 0.24;
        var marginBottomIn = 0.24;
        var marginLeftIn = 0.30;
        var marginRightIn = 0.30;
        var compactMode = val(arguments.expectedUserCount) GT 100;
        var headerHeightIn = compactMode ? 0.44 : 0.60;
        var verticalGapIn = compactMode ? 0.06 : 0.08;
        var horizontalGapIn = 0.08;
        var cardWidthIn = 0.95;
        var cardHeightIn = compactMode ? 0.74 : 0.86;
        var cardImageSizeIn = compactMode ? 0.52 : 0.60;
        var rowsPerPage = compactMode ? 6 : 5;

        var bodyWidthIn = pageWidthIn - marginLeftIn - marginRightIn;
        var bodyHeightIn = pageHeightIn - marginTopIn - marginBottomIn - headerHeightIn;

        var columns = javacast("int", floor((bodyWidthIn + horizontalGapIn) / (cardWidthIn + horizontalGapIn)));
        var rows = javacast("int", floor((bodyHeightIn + verticalGapIn) / (cardHeightIn + verticalGapIn)));

        if (columns LT 1) {
            columns = 1;
        }
        if (rows LT 1) {
            rows = 1;
        }

        // Per user request: <=100 uses 5x10 pages, >100 uses 6x10 compact pages.
        var cardsPerFirstPage = columns * rowsPerPage;
        var cardsPerContinuationPage = columns * rowsPerPage;
        var cardsPerPage = cardsPerFirstPage;
        var maxSupportedCount = cardsPerFirstPage + cardsPerContinuationPage;
        var headerImageMaxWidthIn = 4.8;
        var headerImageWeb = fileExists(expandPath("/assets/images/college-of-optometry-tertiary.png"))
            ? "/assets/images/college-of-optometry-tertiary.png"
            : "/assets/images/uh.png";
        var headerImageAbsolutePath = expandPath(headerImageWeb);
        var headerImageFileURI = "file:///" & replace(headerImageAbsolutePath, "\\", "/", "all");

        return {
            pageOrientation = "landscape",
            pageWidthIn = pageWidthIn,
            pageHeightIn = pageHeightIn,
            marginTopIn = marginTopIn,
            marginBottomIn = marginBottomIn,
            marginLeftIn = marginLeftIn,
            marginRightIn = marginRightIn,
            headerHeightIn = headerHeightIn,
            cardWidthIn = cardWidthIn,
            cardHeightIn = cardHeightIn,
            verticalGapIn = verticalGapIn,
            horizontalGapIn = horizontalGapIn,
            columns = columns,
            rows = rows,
            cardsPerPage = cardsPerPage,
            firstPageRows = rowsPerPage,
            continuationPageRows = rowsPerPage,
            cardsPerFirstPage = cardsPerFirstPage,
            cardsPerPageWithoutHeader = cardsPerContinuationPage,
            maxSupportedCount = maxSupportedCount,
            compactMode = compactMode,
            cardImageSizeIn = cardImageSizeIn,
            headerImageMaxWidthIn = headerImageMaxWidthIn,
            fallbackImage = "/assets/images/uh.png",
            // Keep web path for admin UI, but use file URI in PDF template for reliability.
            headerImage = headerImageWeb,
            headerImageURI = headerImageFileURI
        };
    }

    public struct function estimatePages( required numeric userCount ) {
        var layout = getLayoutConfig(arguments.userCount);
        var count = max(0, int(arguments.userCount));
        var firstCap = layout.cardsPerFirstPage;
        var nextCap = layout.cardsPerPageWithoutHeader;
        var projectedPages = 0;

        if (count GT 0) {
            if (count LTE firstCap) {
                projectedPages = 1;
            } else {
                projectedPages = 1 + ceiling((count - firstCap) / nextCap);
            }
        }

        return {
            userCount = count,
            cardsPerPage = layout.cardsPerPage,
            cardsPerFirstPage = firstCap,
            cardsPerPageWithoutHeader = nextCap,
            maxSupportedCount = layout.maxSupportedCount,
            projectedPages = projectedPages,
            exceedsTwoPages = projectedPages GT 2
        };
    }

    private void function _validateProgram( required string programName ) {
        var normalized = trim(arguments.programName ?: "");
        var allowed = getProgramOptions();

        for (var item in allowed) {
            if (compareNoCase(item.value, normalized) EQ 0) {
                return;
            }
        }

        throw(type = "Roster.InvalidProgram", message = "Invalid program selection.");
    }

    private string function _buildFullName( required struct person ) {
        var parts = [];

        if (len(trim(person.FIRSTNAME ?: ""))) {
            arrayAppend(parts, trim(person.FIRSTNAME));
        }
        if (len(trim(person.MIDDLENAME ?: ""))) {
            arrayAppend(parts, trim(person.MIDDLENAME));
        }
        if (len(trim(person.LASTNAME ?: ""))) {
            arrayAppend(parts, trim(person.LASTNAME));
        }

        return arrayToList(parts, " ");
    }

    private string function _resolveImageURL( required struct person ) {
        var thumb = trim(person.WEBTHUMBIMAGE ?: "");

        if (len(thumb)) {
            return thumb;
        }

        return _toFileURI("/assets/images/uh.png");
    }

    private string function _toFileURI( required string webPath ) {
        var absPath = expandPath(arguments.webPath);
        return "file:///" & replace(absPath, "\\", "/", "all");
    }

}