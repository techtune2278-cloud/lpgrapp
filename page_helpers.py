"""Liens sortants et sélection d’abonnement."""
import re


def external_links(markup):
    def update(match):
        attrs = match.group(1)
        href = re.search(r'\bhref="([^"]+)"', attrs)
        if not href:
            return match.group(0)
        value = href.group(1)
        if not (value.startswith(('https://', 'http://')) or value.split('?')[0].lower().endswith('.pdf')):
            return match.group(0)
        attrs = re.sub(r'\s+(target|rel)="[^"]*"', '', attrs)
        return '<a' + attrs + ' target="_blank" rel="noopener noreferrer">'
    return re.sub(r'<a\b([^>]*)>', update, markup)


def subscription_books(books):
    """Titres dont les conditions permettent une demande de paiement."""
    return [book for book in books if book.get('subscription_payable')]
