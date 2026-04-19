<cfset application.userReviewAuthService.logout()>
<cflocation url="/UserReview/login.cfm?msg=#urlEncodedFormat('You have been signed out.')#" addtoken="false">