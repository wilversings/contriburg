import QtQuick
import QtTest
import "../contents/ui/DataFetcher.js" as DataFetcher

TestCase {
    id: root
    name: "DataFetcherTests"

    // ---- fetchContributions: synchronous validation paths only.
    // The success paths (fetchWithGraphQL / fetchGithubContributionsPage /
    // fetchGitlabCalendar's 200 branch) all hit real network endpoints and
    // are intentionally not covered here.

    function test_fetchContributions_requiresUsername() {
        var callbackCalled = false
        var errorMessage = ""
        DataFetcher.fetchContributions("github", "", "token", "", function() {
            callbackCalled = true
        }, function(err) {
            errorMessage = err
        })
        compare(callbackCalled, false)
        compare(errorMessage, "Username is required.")
    }

    function test_fetchContributions_unknownPlatform() {
        var errorMessage = ""
        DataFetcher.fetchContributions("bitbucket", "someuser", "", "", function() {
            fail("callback should not be called for an unknown platform")
        }, function(err) {
            errorMessage = err
        })
        verify(errorMessage.indexOf("Unknown platform") !== -1, "error should mention the unknown platform: " + errorMessage)
    }

    function test_fetchContributions_githubRequiresToken_fallsBackToScraper() {
        // With no token, the github branch should NOT hard-fail: it should
        // attempt the tokenless scraper path instead (which will itself hit
        // the network and fail/succeed asynchronously). We only assert that
        // fetchContributions does not synchronously report a "token required"
        // error, since that behavior was intentionally removed.
        var errorMessage = ""
        DataFetcher.fetchContributions("github", "someuser", "", "", function() {}, function(err) {
            errorMessage = err
        })
        verify(errorMessage.indexOf("token") === -1, "should not synchronously demand a token: " + errorMessage)
    }

    // ---- fetchGitlabCalendar: only the synchronous https-validation path.

    function test_fetchGitlabCalendar_rejectsNonHttpsInstanceUrl() {
        var errorMessage = ""
        DataFetcher.fetchContributions("gitlab", "someuser", "", "http://gitlab.example.com", function() {
            fail("callback should not be called for a non-https instance URL")
        }, function(err) {
            errorMessage = err
        })
        verify(errorMessage.indexOf("https://") !== -1, "error should mention https:// requirement: " + errorMessage)
    }

    // ---- gitlabContributionLevel: pure threshold function.

    function test_gitlabContributionLevel_thresholds() {
        compare(DataFetcher.gitlabContributionLevel(0), 0)
        compare(DataFetcher.gitlabContributionLevel(1), 1)
        compare(DataFetcher.gitlabContributionLevel(3), 1)
        compare(DataFetcher.gitlabContributionLevel(4), 2)
        compare(DataFetcher.gitlabContributionLevel(6), 2)
        compare(DataFetcher.gitlabContributionLevel(7), 3)
        compare(DataFetcher.gitlabContributionLevel(9), 3)
        compare(DataFetcher.gitlabContributionLevel(10), 4)
        compare(DataFetcher.gitlabContributionLevel(500), 4)
    }

    // ---- parseGithubContributionsHtml: pure HTML-scraping function.
    // Fixture mirrors GitHub's real markup shape (checked against a live
    // profile page): <td class="ContributionCalendar-day" data-date=""
    // data-level="" id="">, with counts in a separate <tool-tip for="<id>">
    // element, and cells listed out of chronological order like the real page.

    function githubFixture(extra) {
        return `
            <td tabindex="0" data-date="2026-01-03" id="contribution-day-component-2-0" data-level="2" class="ContributionCalendar-day"></td>
            <td tabindex="0" data-date="2026-01-01" id="contribution-day-component-0-0" data-level="0" class="ContributionCalendar-day"></td>
            <td tabindex="0" data-date="2026-01-02" id="contribution-day-component-1-0" data-level="1" class="ContributionCalendar-day"></td>
            ${extra || ""}
            <tool-tip for="contribution-day-component-2-0" class="sr-only">5 contributions on January 3rd.</tool-tip>
            <tool-tip for="contribution-day-component-0-0" class="sr-only">No contributions on January 1st.</tool-tip>
            <tool-tip for="contribution-day-component-1-0" class="sr-only">1 contribution on January 2nd.</tool-tip>
        `
    }

    function test_parseGithubContributionsHtml_sortsChronologically() {
        var days = DataFetcher.parseGithubContributionsHtml(githubFixture())
        compare(days.length, 3)
        compare(days[0].date, "2026-01-01")
        compare(days[1].date, "2026-01-02")
        compare(days[2].date, "2026-01-03")
    }

    function test_parseGithubContributionsHtml_extractsCountsAndLevels() {
        var days = DataFetcher.parseGithubContributionsHtml(githubFixture())
        // days[0] = 2026-01-01, "No contributions" -> count 0, level 0
        compare(days[0].count, 0)
        compare(days[0].level, 0)
        // days[1] = 2026-01-02, "1 contribution" (singular) -> count 1, level 1
        compare(days[1].count, 1)
        compare(days[1].level, 1)
        // days[2] = 2026-01-03, "5 contributions" -> count 5, level 2
        compare(days[2].count, 5)
        compare(days[2].level, 2)
    }

    function test_parseGithubContributionsHtml_ignoresUnrelatedTds() {
        var extra = '<td data-date="2026-01-04" id="some-other-cell" data-level="4" class="SomeOtherWidget"></td>'
        var days = DataFetcher.parseGithubContributionsHtml(githubFixture(extra))
        compare(days.length, 3, "the unrelated <td> should not be counted as a day")
    }

    function test_parseGithubContributionsHtml_emptyOnUnrecognizedMarkup() {
        var days = DataFetcher.parseGithubContributionsHtml("<html><body>GitHub changed everything</body></html>")
        compare(days.length, 0)
    }
}
