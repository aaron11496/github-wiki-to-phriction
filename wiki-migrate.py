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
  wiki-migrate.py fix PHABRICATOR_URL API_TOKEN
  wiki-migrate.py migrate PHABRICATOR_URL API_TOKEN GITHUB_WIKI_PATH [SLUG_PREFIX]

Arguments:
  GITHUB_WIKI_PATH	the local path for github wiki repository.
  SLUG_PREFIX		optional, used to put all migrated wiki pages under the wiki hierarchy. I.E. to put all wikis under 'server/', just specify the argument as 'server/'.
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
        wiki_path = args['GITHUB_WIKI_PATH']
        slug_prefix = args['SLUG_PREFIX']
        migrate(phab_url, api_token, wiki_path, slug_prefix)


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


def migrate(phab_url, api_token, wiki_path, slug_prefix):
    files = glob.glob(os.path.join(wiki_path, '*.md'))
    files.extend(glob.glob(os.path.join(wiki_path, '*.markdown')))
    failed_files = []
    for fname in files:
        bname = os.path.splitext(os.path.basename(fname))[0]
        title = string.capwords(bname.replace('-', ' '))
        slug = title.lower()
        slug = re.sub('[^a-z]', '_', slug)
        slug = re.sub('_{2,}', '_', slug)
        if slug_prefix:
            slug = slug_prefix + slug

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
        try:
            resp.raise_for_status()
            print 'Response:', resp.json()
        except Exception as e:
            failed_files.append({'name': fname, 'err': str(e)})

        print

    if len(failed_files) > 0:
        print '**************************************************************'
        print 'Failed files: '
        for failed_file in failed_files:
            print failed_file['name']
            print failed_file['err']

if __name__ == '__main__':
    main()
