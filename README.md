# Browser

Browser is an open-source fork of [Bromite](https://www.bromite.org/) which is based on [Chromium](https://www.chromium.org/Home) licensed and distributed under [The GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html). It has several additional changes to improve user experience, security, and privacy. It is shipped as the default browser on /e/ OS.

## Enhancements
Following are the enhancements offered by Browser over bromite:
- Disabled by default:
    - Autofill,
    - Async DNS
- Enabled by default:
    - [Do Not Track](https://en.wikipedia.org/wiki/Do_Not_Track),
    - Custom Tabs,
    - Search Suggestions
- Restrict pre-populated search engines to:
    - [DuckDuckGo](https://duckduckgo.com/)
    - [DuckDuckGo Lite](https://lite.duckduckgo.com/lite)
    - [Qwant](https://www.qwant.com/)
    - [espot](https://spot.ecloud.global/)
- Remove **Google** and **Chrome** mentions from various strings wherever applicable feature/services were not reliant on the same

## Artifacts
Browser is built using the [GitLab's CI/CD](https://docs.gitlab.com/ee/ci/). You can access the pipelines for this repository [here](https://gitlab.e.foundation/e/apps/browser/-/pipelines). You can download the job artifacts from the pipelines by following instructions from this [page](https://docs.gitlab.com/ee/ci/pipelines/job_artifacts.html#download-job-artifacts).

## Development
- Documentation regarding development can be found on this repository's [wiki](https://gitlab.e.foundation/e/apps/browser/-/wikis/home)

- A the list of contributors can be viewed on this repository's [contributors graph](https://gitlab.e.foundation/e/apps/browser/-/graphs/master).

In case you wish to contribute to the development of this project, feel free to open a [Merge Request](https://gitlab.e.foundation/e/apps/browser/-/merge_requests) or an [Issue](https://gitlab.e.foundation/e/backlog/-/issues/) for the same. Contributions are always welcome.
