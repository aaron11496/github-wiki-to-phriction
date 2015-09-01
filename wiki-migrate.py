"""GitHub-Wiki-to-Phriction

A tool for migrating your wiki from GitHub to Phriction using Pandoc and
Conduit.

Very much a work in progress. But it kinda works.

`fix` is for changing hyphens to underscores in phriction page names. You need
that if you want easy page linking. Not tested yet.

`migrate` will take a git-cloned GitHub Wiki and push it to Phriction via
Conduit. It worked for me once. You can switch phriction.create to
phriction.edit to try again without having to delete everything.

Usage:
  wiki-migrate fix PHABRICATOR_URL API_TOKEN
  wiki-migrate migrate PHABRICATOR_URL API_TOKEN

"""
from docopt import docopt

import glob
import os
import re
import requests
import string
import sys
import urlparse
from lxml import html

from sh import pandoc
from StringIO import StringIO


def main():
    args = docopt(__doc__)
    phab_url = args['PHABRICATOR_URL']
    api_token = args['API_TOKEN']

    if args['fix']:
        fix(phab_url, api_token)
    if args['migrate']:
        migrate(phab_url, api_token)


def fix(phab_url, api_token):
    with open('srp.html') as f:
        tree = html.fromstring(f.read())

    urls_to_fix = [
        x.text for x in tree.cssselect('ul.phui-object-item-list-view li li')
        if x.text and '-' in x.text]
    for url in urls_to_fix:
        old_slug = url[3:].strip('/').strip('-')
        new_slug = old_slug.replace('-', '_')
        print old_slug, '=>', new_slug

        resp = requests.get(
            urlparse.urljoin(phab_url, '/api/phriction.info'),
            data={'api.token': api_token, 'slug': old_slug})

        resp.raise_for_status()


def migrate(phab_url, api_token):
    for fname in glob.glob(sys.argv[1] + '/*.md'):
        bname = os.path.basename(fname)[:-3]
        title = string.capwords(bname.replace('-', ' '))
        slug = title.lower()
        slug = re.sub('[^a-z]', '_', slug)
        slug = re.sub('_{2,}', '_', slug)

        print fname
        print title
        print slug

        remarkup_f = StringIO()
        with open(fname) as f:
            pandoc('--from', 'markdown_github-yaml_metadata_block',
                   to='remarkup.lua',
                   _in=f,
                   _out=remarkup_f)
        remarkup_f.seek(0)

        data = {'api.token': api_token,
                'slug': slug,
                'title': title,
                'content': remarkup_f.read()}
        resp = requests.get(
            urlparse.urljoin(phab_url, '/api/phriction.create'),
            data=data)
        resp.raise_for_status()
        print 'Response:', resp.json()
        print


if __name__ == '__main__':
    main()
