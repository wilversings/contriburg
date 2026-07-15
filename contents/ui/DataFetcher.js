.pragma library

function fetchContributions(platform, username, token, gitlabInstanceUrl, callback, errorCallback) {
    if (!username) {
        errorCallback("Username is required.");
        return;
    }

    if (platform === "gitlab") {
        fetchGitlabCalendar(username, gitlabInstanceUrl, callback, errorCallback);
    } else if (platform === "github") {
        if (token) {
            fetchWithGraphQL(username, token, callback, errorCallback);
        } else {
            fetchGithubContributionsPage(username, callback, errorCallback);
        }
    } else {
        errorCallback("Unknown platform: " + platform);
    }
}

var CONTRIBUTION_LEVEL_MAP = {
    "NONE": 0,
    "FIRST_QUARTILE": 1,
    "SECOND_QUARTILE": 2,
    "THIRD_QUARTILE": 3,
    "FOURTH_QUARTILE": 4
};

function fetchWithGraphQL(username, token, callback, errorCallback) {
    var xhr = new XMLHttpRequest();
    xhr.open("POST", "https://api.github.com/graphql");
    xhr.setRequestHeader("Authorization", "bearer " + token);
    xhr.setRequestHeader("Content-Type", "application/json");

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        if (xhr.status !== 200) {
            errorCallback("GraphQL API error: " + xhr.status + " " + xhr.statusText);
            return;
        }

        try {
            var response = JSON.parse(xhr.responseText);
            if (response.errors) {
                errorCallback(response.errors[0].message);
                return;
            }
            var weeks = response.data.user.contributionsCollection.contributionCalendar.weeks;
            var days = [];
            for (var i = 0; i < weeks.length; i++) {
                var weekDays = weeks[i].contributionDays;
                for (var j = 0; j < weekDays.length; j++) {
                    var day = weekDays[j];
                    var level = CONTRIBUTION_LEVEL_MAP[day.contributionLevel];
                    days.push({
                        date: day.date,
                        count: day.contributionCount,
                        level: level !== undefined ? level : 0
                    });
                }
            }
            callback(days);
        } catch (e) {
            errorCallback("Error parsing GraphQL response.");
        }
    };

    var query = `
    query($userName:String!) {
        user(login: $userName){
            contributionsCollection {
                contributionCalendar {
                    totalContributions
                    weeks {
                        contributionDays {
                            contributionCount
                            date
                            contributionLevel
                        }
                    }
                }
            }
        }
    }`;

    var body = JSON.stringify({
        query: query,
        variables: { userName: username }
    });

    xhr.send(body);
}

// Public, unauthenticated fallback for tokenless GitHub use: github.com renders
// the same contribution calendar on the public profile page, no login required.
// Each day is a <td class="ContributionCalendar-day" data-date="…" data-level="0-4"
// id="contribution-day-component-…">, with its contribution count carried in a
// separate <tool-tip for="that id">N contributions on …</tool-tip> element.
function fetchGithubContributionsPage(username, callback, errorCallback) {
    var xhr = new XMLHttpRequest();
    var url = "https://github.com/users/" + encodeURIComponent(username) + "/contributions";
    xhr.open("GET", url);

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;

        if (xhr.status === 404) {
            errorCallback("GitHub user not found.");
            return;
        }
        if (xhr.status !== 200) {
            errorCallback("GitHub error: " + xhr.status + " " + xhr.statusText);
            return;
        }

        try {
            var days = parseGithubContributionsHtml(xhr.responseText);
            if (days.length === 0) {
                errorCallback("Could not parse contributions. GitHub may have changed their page layout.");
                return;
            }
            callback(days);
        } catch (e) {
            errorCallback("Error parsing GitHub contributions page.");
        }
    };

    xhr.send();
}

function parseGithubContributionsHtml(html) {
    // Counts live in <tool-tip for="<td id>">N contribution(s) on <date>.</tool-tip>,
    // separate from the <td> itself; index them by the id they describe.
    var countsById = {};
    var tooltipRegex = /<tool-tip\b([^>]*)>([^<]*)<\/tool-tip>/g;
    var tooltipMatch;
    while ((tooltipMatch = tooltipRegex.exec(html)) !== null) {
        var forMatch = /\bfor="([^"]+)"/.exec(tooltipMatch[1]);
        if (!forMatch) continue;
        var countMatch = /^\s*(\d+)/.exec(tooltipMatch[2]);
        countsById[forMatch[1]] = countMatch ? parseInt(countMatch[1], 10) : 0;
    }

    // The grid is emitted row-major (all weeks of day-of-week 0, then day-of-week 1, …),
    // not chronologically, so every day must carry its own date and be sorted afterwards.
    var days = [];
    var tdRegex = /<td\b([^>]*)>/g;
    var tdMatch;
    while ((tdMatch = tdRegex.exec(html)) !== null) {
        var attrs = tdMatch[1];
        if (attrs.indexOf("ContributionCalendar-day") === -1) continue;

        var dateMatch = /data-date="([^"]+)"/.exec(attrs);
        var levelMatch = /data-level="(\d+)"/.exec(attrs);
        var idMatch = /\bid="([^"]+)"/.exec(attrs);
        if (!dateMatch || !levelMatch || !idMatch) continue;

        days.push({
            date: dateMatch[1],
            level: parseInt(levelMatch[1], 10),
            count: countsById[idMatch[1]] || 0
        });
    }

    days.sort(function(a, b) { return a.date < b.date ? -1 : a.date > b.date ? 1 : 0; });
    return days;
}

// calendar.json is GitLab's web-profile endpoint, not the /api/v4 REST API: it
// authenticates via session cookie (or a separate feed token), not a personal
// access token, so this only ever fetches public contribution data.
function fetchGitlabCalendar(username, instanceUrl, callback, errorCallback) {
    var base = (instanceUrl || "https://gitlab.com").trim().replace(/\/+$/, "");
    if (!/^https:\/\//i.test(base)) {
        errorCallback("GitLab Instance URL must start with https://");
        return;
    }

    var xhr = new XMLHttpRequest();
    var url = base + "/users/" + encodeURIComponent(username) + "/calendar.json";
    xhr.open("GET", url);

    xhr.onreadystatechange = function() {
        if (xhr.readyState !== XMLHttpRequest.DONE) return;
        
        if (xhr.status === 200) {
            try {
                var calendar = JSON.parse(xhr.responseText);
                var dates = Object.keys(calendar).sort();
                // Keep roughly the last year, matching the GitHub calendar's range.
                var recentDates = dates.slice(-371);
                var days = recentDates.map(function(date) {
                    var count = calendar[date] || 0;
                    return { date: date, count: count, level: gitlabContributionLevel(count) };
                });
                callback(days);
            } catch (e) {
                errorCallback("Error parsing GitLab calendar response.");
            }
        } else if (xhr.status === 404) {
            errorCallback("GitLab user not found.");
        } else {
            errorCallback("GitLab API error: " + xhr.status + " " + xhr.statusText);
        }
    };

    xhr.send();
}

function gitlabContributionLevel(count) {
    if (count === 0) return 0;
    if (count <= 3) return 1;
    if (count <= 6) return 2;
    if (count <= 9) return 3;
    return 4;
}