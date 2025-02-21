# /e/OS Browser

/e/OS Browser is an open-source fork of [Cromite](https://github.com/uazo/cromite) (Fork of bromite) which is based on [Chromium](https://www.chromium.org/Home) licensed and distributed under [The GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.en.html). It has several additional changes to improve user experience, security, and privacy. It is shipped as the default browser on /e/OS.

## Enhancements
Following are the enhancements offered by Browser over cromite:
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
    - [Mojeek](https://www.mojeek.com/)
- Remove **Google** and **Chrome** mentions from various strings wherever applicable feature/services were not reliant on the same

## /e/OS Browser Filters

- The /e/OS Browser uses the filter.dat file created by generate_filters.sh to block advertisements.
- Easyprivacy.txt and Easylist.txt are converted to filters.dat file using ruleset_converter, a program built from the chrome source code.
- The most recent bin is available in the x64 arch artifacts at https://gitlab.e.foundation/e/os/browser/-/pipelines.
- The file filters.dat is updated on a weekly basis and hosted on the /e/OS ota server at https://images.ecloud.global/apps/browser/filters.dat.
- The following URL contains documentaion for the feature https://doc.e.foundation/browser-custom-filters.

## Artifacts
Browser is built using the [GitLab's CI/CD](https://docs.gitlab.com/ee/ci/). You can access the pipelines for this repository [here](https://gitlab.e.foundation/e/os/browser/-/pipelines). You can download the job artifacts from the pipelines by following instructions from this [page](https://docs.gitlab.com/ee/ci/pipelines/job_artifacts.html#download-job-artifacts).

## Development
- Documentation regarding development can be found on this repository's [wiki](https://gitlab.e.foundation/e/os/browser/-/wikis/home)
- A the list of contributors can be viewed on this repository's [contributors graph](https://gitlab.e.foundation/e/os/browser/-/graphs/master).

In case you wish to contribute to the development of this project, feel free to open a [Merge Request](https://gitlab.e.foundation/e/os/browser/-/merge_requests) or an [Issue](https://gitlab.e.foundation/e/backlog/-/issues/) for the same. Contributions are always welcome.
