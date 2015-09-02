# github-wiki-to-phriction

I wanted to migrate a GitHub wiki to Phriction so I wrote this tool to do it. It uses a [Pandoc](http://pandoc.org/) custom writer to convert GitHub Markdown to Remarkup.

It's got some bugs, but if you need to migrate it can get you most of the way there. For example, it can't upload images to Phriction so all embedded images you had in GitHub will be replaced with links. I also punted entirely on rendering tables and some other cases, but if someone wants to finish what I started in `remarkup.lua` I'm happy to look at pull requests.
