# Changelog

## [1.1.0](https://github.com/html2rss/html2rss-web/compare/html2rss-web-v1.0.0...html2rss-web/v1.1.0) (2026-05-01)


### Features

* add help text on error page ([eeee345](https://github.com/html2rss/html2rss-web/commit/eeee345ac109cd4dfbadf05bcb8b5cfe74c21517)), closes [#338](https://github.com/html2rss/html2rss-web/issues/338)
* add routed frontend feed creation workflow ([#963](https://github.com/html2rss/html2rss-web/issues/963)) ([2d1b71a](https://github.com/html2rss/html2rss-web/commit/2d1b71a7f9b41e34180cd181066779286498cab3))
* **auto_source:** add support for `auto_source` feature ([#676](https://github.com/html2rss/html2rss-web/issues/676)) ([531dced](https://github.com/html2rss/html2rss-web/commit/531dced02ecd53f9594670b56699ea5d2ab6842e))
* default browserless onboarding and request strategies ([#895](https://github.com/html2rss/html2rss-web/issues/895)) ([377cff0](https://github.com/html2rss/html2rss-web/commit/377cff0612fccba7e6d3962826f82cb89f531fc0))
* **deps:** use html2rss in latest development status ([#728](https://github.com/html2rss/html2rss-web/issues/728)) ([5885d1d](https://github.com/html2rss/html2rss-web/commit/5885d1d17860b6637b80b7f2eda9e58019799f36))
* **docker:** switch to alpine 21 ([7adcc89](https://github.com/html2rss/html2rss-web/commit/7adcc89cc98ac06e9e4e9fe841be0a80509639b7))
* **docker:** upgrade to use ruby 3.3 image ([ceafe24](https://github.com/html2rss/html2rss-web/commit/ceafe24e7400b1410144f417199b9d044b6a2a37))
* **docker:** use multilayer build to cut image size in half ([2f6e322](https://github.com/html2rss/html2rss-web/commit/2f6e322c94776ccd33180061468e6ceaf31a73b4))
* **docker:** use Ruby 3.4 ([4f7d795](https://github.com/html2rss/html2rss-web/commit/4f7d7959cf7c2d53c246b893e8d8558b396d325d))
* **frontend:** polish result experience and validation tooling ([#964](https://github.com/html2rss/html2rss-web/issues/964)) ([b11665e](https://github.com/html2rss/html2rss-web/commit/b11665eb18a9716012e13bfb20cdb535d741cd0c))
* **frontend:** relaunch the app with a focused v1 flow ([e0692d7](https://github.com/html2rss/html2rss-web/commit/e0692d7bc3fb04e0b936f1a2529361fd148a8eb1))
* **frontend:** unify feed/result state flow ([#943](https://github.com/html2rss/html2rss-web/issues/943)) ([6dfa1a9](https://github.com/html2rss/html2rss-web/commit/6dfa1a928445283f08bd6471ec1c247adebb5ef7))
* **health_check:** add HTTP Basic authentication to `GET /health_check.txt` ([#559](https://github.com/html2rss/html2rss-web/issues/559)) ([d0ccd83](https://github.com/html2rss/html2rss-web/commit/d0ccd83ef889e17a1d6ddec037274584237ed161))
* improve example feed config in feed.yml and link to it ([#552](https://github.com/html2rss/html2rss-web/issues/552)) ([de08695](https://github.com/html2rss/html2rss-web/commit/de08695b7d6cfcb8b4b4ae51c5056eb596c8478a))
* install Gemfile.lock specified bundler version ([4190160](https://github.com/html2rss/html2rss-web/commit/41901609ec24bd20b1f80fa02b2cf1a25fcd89e7))
* integrate request_service and use ssrf_filter strategy by default ([#707](https://github.com/html2rss/html2rss-web/issues/707)) ([b7516fd](https://github.com/html2rss/html2rss-web/commit/b7516fda083561c515a0a9c77dee08ead9b54a66))
* link included feeds to the instance feed directory ([#901](https://github.com/html2rss/html2rss-web/issues/901)) ([51ce79a](https://github.com/html2rss/html2rss-web/commit/51ce79af948d279f2e565ca6f375c6855dd659fc))
* optionally allow APM using Sentry via env variable ([#696](https://github.com/html2rss/html2rss-web/issues/696)) ([94477d5](https://github.com/html2rss/html2rss-web/commit/94477d50b178cf519d1e56f82f31e27cacc223c4))
* redact sensitive feed data in structured logs ([#903](https://github.com/html2rss/html2rss-web/issues/903)) ([ee7df73](https://github.com/html2rss/html2rss-web/commit/ee7df738f99704977c2396d4b2261ed7213ef119))
* remove dependency on activesupport ([048cb73](https://github.com/html2rss/html2rss-web/commit/048cb73f74e85376bf71aad973eee076d4c25c84))
* **runtime:** rebuild feed and api behavior around typed v1 services ([b61602d](https://github.com/html2rss/html2rss-web/commit/b61602d0bcf256ea8120ab2dad01aadb8bd17587))
* simplify feed creation contract & backend error handling ([#962](https://github.com/html2rss/html2rss-web/issues/962)) ([dfca027](https://github.com/html2rss/html2rss-web/commit/dfca027e4fc0754213ae8f25eebedb97ca230407))
* stabilize public http interface & slimmer docker ([#882](https://github.com/html2rss/html2rss-web/issues/882)) ([fe3f4be](https://github.com/html2rss/html2rss-web/commit/fe3f4bec9c9096661bd4b404201df94c02a3b833))
* unify web and feed result surfaces ([#896](https://github.com/html2rss/html2rss-web/issues/896)) ([e747b23](https://github.com/html2rss/html2rss-web/commit/e747b2334caf4ee47d0928153225545b25dff073))
* use parallel processing for feed retrieval in health_check.rb ([#665](https://github.com/html2rss/html2rss-web/issues/665)) ([4a24997](https://github.com/html2rss/html2rss-web/commit/4a249979b2ac5caa5402e9d29ef6a09ae62b4ee7))


### Bug Fixes

* ArgumentError when RACK_TIMEOUT_SERVICE_TIMEOUT env var is set ([96acbab](https://github.com/html2rss/html2rss-web/commit/96acbab52151a8c88ed446037a52746349942046)), closes [#527](https://github.com/html2rss/html2rss-web/issues/527)
* **auto_source:** respect headers from global config ([#691](https://github.com/html2rss/html2rss-web/issues/691)) ([3e9ba91](https://github.com/html2rss/html2rss-web/commit/3e9ba91db0cc60d2e5b2312c06ca4be238cbef7f))
* **build:** only cleanup when there is a test container ([f7bafa6](https://github.com/html2rss/html2rss-web/commit/f7bafa6ec9d5be857e3a204816b49c81d92ed131))
* caching with dynamic parameters yields incorrect rss ([#589](https://github.com/html2rss/html2rss-web/issues/589)) ([bb945c2](https://github.com/html2rss/html2rss-web/commit/bb945c239583f82c2db57548665528cc7f6ab330)), closes [#587](https://github.com/html2rss/html2rss-web/issues/587)
* **ci:** repair Ruby, OpenAPI, and frontend checks ([#880](https://github.com/html2rss/html2rss-web/issues/880)) ([ec6673b](https://github.com/html2rss/html2rss-web/commit/ec6673b514ab0225fb63ba5a6f03f247c6b43799))
* defects for token/retry/loading UX ([#924](https://github.com/html2rss/html2rss-web/issues/924)) ([2d38633](https://github.com/html2rss/html2rss-web/commit/2d38633ebeb87534183d23142cf045c0ea6d69ea))
* **docker:** missing curl installation for health check ([0bd9157](https://github.com/html2rss/html2rss-web/commit/0bd9157c013f1aae35bac2d2ca5122fe6c957780))
* example feed in config/feeds.yml broken ([#664](https://github.com/html2rss/html2rss-web/issues/664)) ([b961897](https://github.com/html2rss/html2rss-web/commit/b9618974e7baea0fa24344b158f07dcec8175ed6))
* **frontend:** preserve created feeds when preview loading fails ([#915](https://github.com/html2rss/html2rss-web/issues/915)) ([383ecc3](https://github.com/html2rss/html2rss-web/commit/383ecc3ee8c567eb25d0b5ec2bdec12b2bb9c676))
* **frontend:** streamline web ux ([#916](https://github.com/html2rss/html2rss-web/issues/916)) ([85e79bf](https://github.com/html2rss/html2rss-web/commit/85e79bf016133c280a37fa03cc4b3724f2cb2551))
* harden container config defaults ([392997c](https://github.com/html2rss/html2rss-web/commit/392997cf8e58bdae6714b9573a800d3f652322a0))
* healthcheck broken due to missing curl ([c97e746](https://github.com/html2rss/html2rss-web/commit/c97e7462733ff4d2a7646510c4c3cb8e889ecd58))
* keep unknown api v1 paths inside the api contract ([a820478](https://github.com/html2rss/html2rss-web/commit/a82047832559fd470fd4903d3e611684e24269e9))
* responds with http status 422 ([#738](https://github.com/html2rss/html2rss-web/issues/738)) ([ad9394c](https://github.com/html2rss/html2rss-web/commit/ad9394c4cd18fb7a247dd7b181dee2b472713641))
* **runtime:** polish relaunch smoke behavior and health checks ([65e1644](https://github.com/html2rss/html2rss-web/commit/65e1644e358ed199b633e92634082f8578277689))
* stylesheets not included in feed ([#779](https://github.com/html2rss/html2rss-web/issues/779)) ([9116d9d](https://github.com/html2rss/html2rss-web/commit/9116d9ddace3a4523e72f72db96e7bc9f1fa47f4))
* tzdata package not installed but required for tz conversion ([#663](https://github.com/html2rss/html2rss-web/issues/663)) ([55814d2](https://github.com/html2rss/html2rss-web/commit/55814d2239463a71af9849ad8951142572316bc4))
* **web:** harden feed reader fallback and rss rendering ([#944](https://github.com/html2rss/html2rss-web/issues/944)) ([438d9f6](https://github.com/html2rss/html2rss-web/commit/438d9f63f418af177b299b12835c43f696207d0d))
* **web:** harden observability env handling and Sentry log redaction ([#917](https://github.com/html2rss/html2rss-web/issues/917)) ([ed2b3e9](https://github.com/html2rss/html2rss-web/commit/ed2b3e99b3b806f5826485a6c20079068a444c7d))


### Performance Improvements

* enable YJIT ([729f31f](https://github.com/html2rss/html2rss-web/commit/729f31f1b9160971a02a9ba855c880113534368e))

## Changelog

All notable changes to this project will be documented in this file.
