.pragma library

function fetchContributions(platform, username, token, gitlabInstanceUrl, callback, errorCallback) {
    if (!username) {
        errorCallback("Username is required.");
        return;
    }

    if (platform === "gitlab") {
        fetchGitlabCalendar(username, gitlabInstanceUrl, token, callback, errorCallback);
    } else if (platform === "github") {
        fetchWithGraphQL(username, token, callback, errorCallback);
    }
}

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
                    var levelMap = {
                        "NONE": 0,
                        "FIRST_QUARTILE": 1,
                        "SECOND_QUARTILE": 2,
                        "THIRD_QUARTILE": 3,
                        "FOURTH_QUARTILE": 4
                    };
                    days.push({
                        date: day.date,
                        count: day.contributionCount,
                        level: levelMap[day.contributionLevel] !== undefined ? levelMap[day.contributionLevel] : 0
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

function fetchGitlabCalendar(username, instanceUrl, token, callback, errorCallback) {
    var xhr = new XMLHttpRequest();
    var base = (instanceUrl || "https://gitlab.com").replace(/\/+$/, "");
    var url = base + "/users/" + encodeURIComponent(username) + "/calendar.json";
    xhr.open("GET", url);
    if (token) {
        xhr.setRequestHeader("PRIVATE-TOKEN", token);
    }

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