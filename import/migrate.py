#!/usr/bin/env python

import re
import os
import sys
import yaml
import tempfile
import codecs
from dtutils import gmt1
from xml.etree.ElementTree import ElementTree
from subprocess import call, PIPE, Popen
from datetime import datetime
from glob import glob
from BeautifulSoup import BeautifulSoup
from urlparse import urlparse, urljoin
from urllib import urlretrieve

"""
Migrate a Wordpress blog to jekyll.

Based on exitwp by Thomas Froessman <https://github.com/thomasf/exitwp>,
with some modifications to preserve useful metadata for DISQUS and more.
"""

POST_STATUS_MAP = {
    'publish': '_posts',
}

class MigrateConf(object):
    """Global configuration settings for migrate.py"""
    def __init__(self):
        """Initialize with default settings"""
        self.wp_exports = 'wordpress-xml'
        self.build_dir = 'build'
        self.download_images = False
        self.target_format = 'markdown'
        self.taxonomy_filter = frozenset()
        self.taxonomy_entry_filter = {'category': 'Uncategorized'}
        self.taxonomy_name_mapping = {'category': 'categories', 'post_tag': 'tags'}
        self.item_type_filter = frozenset(['attachment', 'nav_menu_item'])
        self.date_format = '%Y-%m-%d %H:%M:%S'

    def filtered_taxonomy(self, domain, entry):
        return (domain in self.taxonomy_filter) or (self.taxonomy_entry_filter.get(domain, None) == entry)

def loadconf(path):
    """Load configuration from specified YAML file"""
    gconf = MigrateConf()
    try:
        with open(path, 'r') as f:
            config = yaml.load(f)
        gconf.wp_exports = config['wp_exports']
        gconf.build_dir = config['build_dir']
        gconf.download_images = config['download_images']
        gconf.target_format = config['target_format']
        gconf.taxonomy_filter = frozenset(config['taxonomies']['filter'])
        gconf.taxonomy_entry_filter = config['taxonomies']['entry_filter']
        gconf.taxonomy_name_mapping = config['taxonomies']['name_mapping']
        gconf.item_type_filter = frozenset(config['item_type_filter'])
        gconf.date_format = config['date_format']
    except IOError, OSError:
        # Continue with defaults
        # FIXME: report exception
        pass
    except KeyError:
        # FIXME: better error reporting
        raise
    return gconf

def html_to_format(html, target_format='markdown'):
    if target_format == 'html':
        return html
    elif target_format == 'markdown':
        pid = Popen(['pandoc', '-f', 'html', '-t', 'markdown', '--strict'], stdin=PIPE, stdout=PIPE)
        incoming = pid.communicate(html.encode('utf-8'))[0]
        return incoming.decode('utf-8')
    else:
        raise ValueError("Invalid format %r" % target_format)

# The following regexps are quite heavy, precompile them beforehand
ALLBLOCKS = r'(?:table|thead|tfoot|caption|col|colgroup|tbody|tr|td|th|div|dl|dd|dt|ul|ol|li|pre|select|option|form|map|area|blockquote|address|math|style|input|p|h[1-6]|hr|fieldset|legend|section|article|aside|hgroup|header|footer|nav|figure|figcaption|details|menu|summary)'
AUTOP_ALLBLOCKS_OPEN  = re.compile(r'(<' + ALLBLOCKS + r'[^>]*>)')
AUTOP_ALLBLOCKS_CLOSE = re.compile(r'(</' + ALLBLOCKS + r'>)')
AUTOP_PRESERVE_TAGS = re.compile(r'<p>\s*(</?' + ALLBLOCKS + r'[^>]*>)\s*</p>')
AUTOP_REDUNDANT_P1 = re.compile(r'<p>\s*(</?' + ALLBLOCKS + r'[^>]*>)')
AUTOP_REDUNDANT_P2 = re.compile(r'(</?' + ALLBLOCKS + r'[^>]*>)\s*</p>')
AUTOP_STRIP_BR = re.compile(r'(</?' + ALLBLOCKS + r'[^>]*>)\s*<br />')

def wpautop(html, br=True):
    """Perform automatic <p> tag generation a-la-Wordpress."""

    _preserve_newline_pseudotag = u'<WPPreserveNewline />'

    def _newline_preservation_helper(m):
        return m.group(0).replace(u'\n', _preserve_newline_pseudotag)

    def _clean_pre(m):
        txt = m.group(1) + m.group(2) + u'</pre>'
        return txt.replace(u'<br />', u'').replace(u'<p>', u'\n').replace(u'</p>', u'')

    # Ensure we're dealing with unicode
    assert isinstance(html, unicode), "Something is REALLY wrong - expected unicode, got %s" % type(html).__name__
    if len(html.strip()) == 0:
        return u''
    # Pad the end
    html += u'\n'
    html = re.sub(r'<br />\s*<br />', r'\n\n', html)
    html = AUTOP_ALLBLOCKS_OPEN.sub(r'\n\1', html)
    html = AUTOP_ALLBLOCKS_CLOSE.sub(r'\1\n\n', html)
    html = html.replace(u'\r\n', u'\n').replace(u'\r', u'\n')
    if html.find('<object') > -1:
        html = re.sub(r'\s*<param([^>]*)>\s*', r'<param\1>', html) # Leave object params alone
        html = re.sub(r'\s*</embed>\s*', r'</embed>', html)
    html = re.sub(r'\n{2,}', r'\n\n', html) # Remove duplicates
    # Now make paragraphs, including one at the end
    paragraphs = re.split(r'\n\s*\n', html)
    html = []
    for paragraph in paragraphs:
        if len(paragraph) == 0:
            continue
        html.append(u'<p>' + paragraph.strip(u'\n') + u'</p>')
    html = u'\n'.join(html) + u'\n'
    html = re.sub(r'<p>\s*</p>', r'', html) # Kill paragraphs made up entirely of empty spaces - FIXME: we could detect this earlier in the loop
    html = re.sub(r'<p>([^<]+)</(div|address|form)>', r'<p>\1</p></\2>', html) # Fix bad closing tags
    html = AUTOP_PRESERVE_TAGS.sub(r'\1', html) # Don't touch tags
    html = re.sub(r'<p>(<li.+?)</p>', r'\1', html) # Leave lists alone
    html = re.sub(r'(?i)<p><blockquote([^>]*)>', r'<blockquote\1><p>', html) # Handle blockquote opening
    html = html.replace(u'</blockquote></p>', u'</p></blockquote>') # and closing
    html = AUTOP_REDUNDANT_P1.sub(r'\1', html)
    html = AUTOP_REDUNDANT_P2.sub(r'\1', html)
    if br:
        html = re.sub(r'(?s)<(script|style).*?</\\1>', _newline_preservation_helper, html)
        html = re.sub(r'(?<!<br />)\s*\n', r'<br />\n', html)
        html = html.replace(_preserve_newline_pseudotag, u'\n')
    html = AUTOP_STRIP_BR.sub(r'\1', html)
    html = re.sub(r'<br />(\s*</?(?:p|li|div|dl|dd|dt|th|pre|td|ul|ol)[^>]*>)', r'\1', html)
    if html.find(u'<pre') > -1:
        html = re.sub(r'(?is)(<pre[^>]*>)(.*?)</pre>', _clean_pre, html)
    html = re.sub(r'\n</p>$', r'</p>', html)

    return html


def parse_wp_xml(fpath, config):
    """Parse a Wordpress XML export"""
    # XML namespaces
    ns = {
        '':'',      # default namespace
        'excerpt':  "{http://wordpress.org/export/1.1/excerpt/}",
        'content':  "{http://purl.org/rss/1.0/modules/content/}",
        'wfw':      "{http://wellformedweb.org/CommentAPI/}",
        'dc':       "{http://purl.org/dc/elements/1.1/}",
        'wp':       "{http://wordpress.org/export/1.1/}"
    }

    tree = ElementTree()

    print "reading: " + fpath
    root = tree.parse(fpath)
    c = root.find('channel')

    def parse_header():
        return {
            'title':        unicode(c.find('title').text),
            'link':         unicode(c.find('link').text),
            'description':  unicode(c.find('description').text)
        }

    def parse_items():
        export_items = []
        xml_items = c.findall('item')
        sys.stdout.write("parsing")
        for i in xml_items:
            sys.stdout.write(".")
            sys.stdout.flush()
            taxonomies = i.findall('category')
            export_taxonomies = {}
            for tax in taxonomies:
                t_domain = unicode(tax.attrib['domain'])
                t_entry = unicode(tax.text)
                if not config.filtered_taxonomy(t_domain, t_entry):
                    if t_domain not in export_taxonomies:
                        export_taxonomies[t_domain] = []
                    export_taxonomies[t_domain].append(t_entry)

            def gi(q, unicode_wrap=True):
                namespace = ''
                tag = ''
                if q.find(':') > 0:
                    namespace, tag = q.split(':', 1)
                else:
                    tag = q
                result = i.find(ns[namespace]+tag).text
                if unicode_wrap:
                    result = unicode(result)
                return result

            body = wpautop(gi('content:encoded'))

            img_srcs = []
            if body is not None:
                try:
                    soup = BeautifulSoup(body)
                    img_tags = soup.findAll('img')
                    for img in img_tags:
                        img_srcs.append(img['src'])
                except:
                    print "could not parse html: " + body

            export_item = {
                'title':        gi('title'),
                'date':         gi('wp:post_date'),
                'slug':         gi('wp:post_name'),
                'status':       gi('wp:status'),
                'type':         gi('wp:post_type'),
                'wp_id':        gi('wp:post_id'),
                'guid':         gi('guid'),
                'taxonomies':   export_taxonomies,
                'body':         body,
                'img_srcs':     img_srcs
            }

            export_items.append(export_item)

        print ""
        return export_items

    return {
        'header':   parse_header(),
        'items':    parse_items(),
    }

def write_jekyll(data, config):
    sys.stdout.write("writing")
    item_uids = {}
    attachments = {}

    def get_blog_path(data, path_infix='jekyll'):
        name = data['header']['link']
        name = re.sub(r'^https?', '', name)
        name = re.sub(r'[^A-Za-z0-9_.-]', '', name)
        return os.path.normpath(os.path.join(config.build_dir, path_infix, name))

    blog_dir = get_blog_path(data)

    def get_full_dir(dname):
        full_dir = os.path.normpath(os.path.join(blog_dir, dname))
        if not os.path.exists(full_dir):
            os.makedirs(full_dir)
        return full_dir

    def open_file(fn):
        f = codecs.open(fn, 'w', encoding='utf-8')
        return f

    def get_item_uid(item, date_prefix=False, namespace=''):
        result = None
        if namespace not in item_uids:
            item_uids[namespace] = {}

        if item['wp_id'] in item_uids[namespace]:
            result = item_uids[namespace][item['wp_id']]
        else:
            uid = []
            if date_prefix:
                dt = datetime.strptime(item['date'], config.date_format)
                uid.append(dt.strftime('%Y-%m-%d'))
                uid.append('-')
            s_title = item['slug']
            if s_title is None or s_title == '':
                s_title = item['title']
            if s_title is None or s_title == '':
                s_title = 'untitled'
            s_title = s_title.replace(' ', '_')
            s_title = re.sub(r'[^a-zA-Z0-9_-]', '', s_title)
            uid.append(s_title)
            fn = ''.join(uid)
            n = 1
            while fn in item_uids[namespace]:
                n += 1
                fn = ''.join(uid) + '_' + str(n)
                item_uids[namespace][i['wp_id']] = fn
            result = fn
        return result

    def get_item_path(item, dname=''):
        full_dir = get_full_dir(dname)
        filename_parts = [item['uid']]
        filename_parts.append('.')
        filename_parts.append(config.target_format)
        return os.path.join(full_dir, ''.join(filename_parts))

    def get_attachment_path(src, dname, dir_prefix='a'):
        try:
            files = attachments[dname]
        except KeyError:
            attachments[dname] = files = {}

        try:
            filename = files[src]
        except KeyError:
            file_root, file_ext = os.path.splitext(os.path.basename(urlparse(src)[2]))
            file_infix = 1
            if file_root == '':
                file_root = '1'
            current_files = files.values()
            maybe_filename = file_root + file_ext
            while maybe_filename in current_files:
                maybe_filename = file_root + '-' + str(file_infix) + file_ext
                file_infix = file_infix + 1
            files[src] = filename = maybe_filename

        target_dir = os.path.normpath(os.path.join(config.blog_dir, dir_prefix, dname))
        target_file = os.path.normpath(os.path.join(target_dir, filename))

        if not os.path.exists(target_dir):
            os.makedirs(target_dir)

        return target_file

    for i in data['items']:
        sys.stdout.write(".")
        sys.stdout.flush()
        out = None
        dt = datetime.strptime(i['date'], config.date_format).replace(tzinfo=gmt1)
        ndate = dt.strftime('%Y-%m-%d %H:%M:%S.000000 %z')
        yaml_header = {
            'title':            i['title'],
            'date':             ndate,
            'slug':             i['slug'],
            'status':           i['status'],
            'wordpress_id':     i['wp_id'],
            'wordpress_guid':   i['guid'],
            'disqus_id':        i['wp_id'] + " " + i['guid'],
        }

        if i['type'] == 'post':
            i['uid'] = get_item_uid(i, date_prefix=True)
            fn = get_item_path(i, dname=POST_STATUS_MAP.get(i['status'], '_drafts'))
            out = open_file(fn)
            yaml_header['layout'] = 'post'
        elif i['type'] == 'page':
            i['uid'] = get_item_uid(i)
            fn = get_item_path(i)
            out = open_file(fn)
            yaml_header['layout'] = 'page'
        elif i['type'] in config.item_type_filter:
            pass
        else:
            print "Unknown item type :: " + i['type']

        if config.download_images:
            for img in i['img_srcs']:
                urlretrieve(urljoin(data['header']['link'], img.decode('utf-8')), get_attachment_path(img, i['uid']))

        if out is not None:
            def toyaml(data):
                return yaml.safe_dump(data, allow_unicode=True, default_flow_style=False).decode('utf-8')

            tax_out = {}
            for taxonomy in i['taxonomies']:
                for tvalue in i['taxonomies'][taxonomy]:
                    t_name = config.taxonomy_name_mapping.get(taxonomy, taxonomy)
                    if t_name not in tax_out:
                        tax_out[t_name] = []
                    tax_out[t_name].append(tvalue)

            out.write('---\n')
            if len(yaml_header) > 0:
                out.write(toyaml(yaml_header))
            if len(tax_out) > 0:
                out.write(toyaml(tax_out))

            out.write('---\n\n')
            out.write(html_to_format(i['body'], config.target_format).rstrip())
            out.write('\n')

            out.flush()
            out.close()

    print "\n"

if __name__ == '__main__':
    config = loadconf("config.yaml")
    wp_exports = glob(os.path.join(config.wp_exports, '*.xml'))
    for wpe in wp_exports:
        data = parse_wp_xml(wpe, config)
        write_jekyll(data, config)

    print 'done'
