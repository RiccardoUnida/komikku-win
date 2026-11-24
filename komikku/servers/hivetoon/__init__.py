# SPDX-FileCopyrightText: 2019-2025 Valéry Febvre
# SPDX-License-Identifier: GPL-3.0-or-later
# Author: Valéry Febvre <vfebvre@easter-eggs.com>

from komikku.servers.multi.heancms import HeanCMS


class Hivetoon(HeanCMS):
    id = 'hivetoon'
    name = 'Hive Toon'
    lang = 'en'

    base_url = 'https://hivetoons.org'
    logo_url = base_url + '/favicon-32x32.png'
    api_url = 'https://api.hivetoons.org/api'
