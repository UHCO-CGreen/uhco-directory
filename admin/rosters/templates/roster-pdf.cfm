<cfscript>
totalUsers = arrayLen(rosterUsers);
cardsFirstPage = max(1, val(layoutConfig.cardsPerFirstPage ?: layoutConfig.cardsPerPage ?: 1));
cardsContinuation = max(1, val(layoutConfig.cardsPerPageWithoutHeader ?: layoutConfig.cardsPerPage ?: 1));

totalPages = 0;
if (totalUsers GT 0) {
    if (totalUsers LTE cardsFirstPage) {
        totalPages = 1;
    } else {
        totalPages = 1 + ceiling((totalUsers - cardsFirstPage) / cardsContinuation);
    }
}
</cfscript>

<cfoutput>
<!doctype html>
<html>
<head>
    <meta charset="utf-8">
    <style>
        body {
            margin: 0;
            padding: 0;
            font-family: Arial, Helvetica, sans-serif;
            color: ##202124;
        }

        .roster-page {
            width: 100%;
            min-height: #layoutConfig.pageHeightIn#in;
        }

        .roster-page.page-break {
            page-break-after: always;
        }

        .roster-header {
            height: #layoutConfig.headerHeightIn#in;
            display: table;
            width: 100%;
            margin: 0 0 0.12in 0;
            border-bottom: 1px solid ##d8dce1;
        }

        .roster-header .header-image {
            display: table-cell;
            vertical-align: middle;
            width: 70%;
        }

        .roster-header .header-title {
            display: table-cell;
            vertical-align: middle;
            text-align: right;
            font-size: 18pt;
            font-weight: 700;
            white-space: nowrap;
        }

        .roster-header img {
            max-width: 4.8in;
            max-height: #layoutConfig.headerHeightIn - 0.10#in;
            width: auto;
            height: auto;
        }

        .roster-grid {
            width: 100%;
            border-collapse: separate;
            border-spacing: #layoutConfig.horizontalGapIn#in #layoutConfig.verticalGapIn#in;
            table-layout: fixed;
        }

        .roster-grid td {
            width: #layoutConfig.cardWidthIn#in;
            height: #layoutConfig.cardHeightIn#in;
            vertical-align: top;
            text-align: center;
            padding: 0;
        }

        .roster-card-image {
            width: #layoutConfig.cardImageSizeIn ?: 0.60#in;
            height: #layoutConfig.cardImageSizeIn ?: 0.60#in;
            object-fit: cover;
            border: 1px solid ##d9dde3;
            border-radius: 2px;
            display: block;
            margin: 0 auto 0.04in auto;
        }

        .roster-card-name {
            font-size: 7pt;
            line-height: 1.15;
            height: 0.22in;
            overflow: hidden;
            word-wrap: break-word;
            font-weight: 600;
        }
    </style>
</head>
<body>

<cfloop from="1" to="#totalPages#" index="pageIndex">
    <cfset showHeader = (pageIndex EQ 1)>
    <cfset thisPageCapacity = showHeader ? cardsFirstPage : cardsContinuation>

    <cfif showHeader>
        <cfset pageStart = 1>
    <cfelse>
        <cfset pageStart = cardsFirstPage + ((pageIndex - 2) * cardsContinuation) + 1>
    </cfif>
    <cfset pageEnd = min(pageStart + thisPageCapacity - 1, totalUsers)>

    <div class="roster-page#pageIndex LT totalPages ? ' page-break' : ''#">
        <cfif showHeader>
            <div class="roster-header">
                <div class="header-image">
                    <img
                        src="#encodeForHTMLAttribute(layoutConfig.headerImageURI ?: layoutConfig.headerImage)#"
                        alt="College of Optometry"
                        style="width:#layoutConfig.headerImageMaxWidthIn ?: 4.8#in; max-width:#layoutConfig.headerImageMaxWidthIn ?: 4.8#in; height:auto;"
                    >
                </div>
                <div class="header-title">Class of #selectedGradYear#</div>
            </div>
        </cfif>

        <table class="roster-grid" role="presentation">
            <tbody>
                <cfset itemsOnPage = pageEnd - pageStart + 1>
                <cfset fullRows = ceiling(itemsOnPage / layoutConfig.columns)>

                <cfloop from="1" to="#fullRows#" index="rowIndex">
                    <tr>
                        <cfloop from="1" to="#layoutConfig.columns#" index="colIndex">
                            <cfset itemOffset = ((rowIndex - 1) * layoutConfig.columns) + colIndex - 1>
                            <cfset globalIndex = pageStart + itemOffset>

                            <td>
                                <cfif globalIndex LTE pageEnd>
                                    <cfset person = rosterUsers[globalIndex]>
                                    <img class="roster-card-image" src="#encodeForHTMLAttribute(person.IMAGEURL)#" alt="#encodeForHTMLAttribute(person.FULLNAME)#">
                                    <div class="roster-card-name">#encodeForHTML(person.FULLNAME)#</div>
                                </cfif>
                            </td>
                        </cfloop>
                    </tr>
                </cfloop>
            </tbody>
        </table>
    </div>
</cfloop>

</body>
</html>
</cfoutput>