import 'package:flutter_test/flutter_test.dart';

import 'package:diaspo_niger/core/errors/exceptions.dart';
import 'package:diaspo_niger/features/gifs/data/datasources/gif_proxy_datasource.dart';
import 'package:diaspo_niger/features/gifs/domain/entities/gif_entity.dart';

/// `gif-proxy` relaie la charge utile du fournisseur **verbatim** : la forme
/// n'est pas la nôtre, elle peut dériver sans prévenir, et c'est le seul
/// endroit où elle est interprétée. D'où ce banc, qui rejoue les deux formes
/// telles que les API les renvoient.
void main() {
  group('Réponse de gif-proxy', () {
    test('Tenor : préfère mediumgif au gif d\'origine', () {
      final gifs = gifsDepuisReponseProxy({
        'provider': 'tenor',
        'payload': {
          'results': [
            {
              'id': 'abc',
              'content_description': 'un chat',
              'media_formats': {
                'gif': {
                  'url': 'https://t.test/abc-plein.gif',
                  'dims': [800, 400],
                },
                'mediumgif': {
                  'url': 'https://t.test/abc-moyen.gif',
                  'dims': [400, 200],
                },
                'tinygif': {'url': 'https://t.test/abc-mini.gif'},
              },
            },
          ],
        },
      });

      expect(gifs, hasLength(1));
      final gif = gifs.single;
      expect(gif.id, 'abc');
      expect(gif.provider, GifProvider.tenor);
      // Le média envoyé est payé en data par chaque destinataire.
      expect(gif.url, 'https://t.test/abc-moyen.gif');
      expect(gif.previewUrl, 'https://t.test/abc-mini.gif');
      expect(gif.aspectRatio, 2.0);
      expect(gif.description, 'un chat');
    });

    test('Tenor : sans mediumgif, retombe sur gif', () {
      final gifs = gifsDepuisReponseProxy({
        'provider': 'tenor',
        'payload': {
          'results': [
            {
              'id': 'abc',
              'media_formats': {
                'gif': {'url': 'https://t.test/abc.gif', 'dims': [100, 100]},
              },
            },
          ],
        },
      });

      expect(gifs.single.url, 'https://t.test/abc.gif');
      expect(gifs.single.previewUrl, 'https://t.test/abc.gif');
    });

    test('Giphy : préfère downsized_medium, ratio pris sur original', () {
      final gifs = gifsDepuisReponseProxy({
        'provider': 'giphy',
        'payload': {
          'data': [
            {
              'id': 'xyz',
              'title': 'un chien',
              'images': {
                // Giphy renvoie ses dimensions en chaînes.
                'original': {
                  'url': 'https://g.test/xyz-plein.gif',
                  'width': '600',
                  'height': '300',
                },
                'downsized_medium': {'url': 'https://g.test/xyz-moyen.gif'},
                'fixed_width_small': {'url': 'https://g.test/xyz-mini.gif'},
              },
            },
          ],
        },
      });

      final gif = gifs.single;
      expect(gif.provider, GifProvider.giphy);
      expect(gif.url, 'https://g.test/xyz-moyen.gif');
      expect(gif.previewUrl, 'https://g.test/xyz-mini.gif');
      expect(gif.aspectRatio, 2.0);
      expect(gif.description, 'un chien');
    });

    test('une entrée sans média est ignorée, pas fatale', () {
      final gifs = gifsDepuisReponseProxy({
        'provider': 'giphy',
        'payload': {
          'data': [
            {'id': 'creux'},
            {
              'id': 'bon',
              'images': {
                'original': {
                  'url': 'https://g.test/bon.gif',
                  'width': '10',
                  'height': '10',
                },
              },
            },
          ],
        },
      });

      // Une entrée malformée ne doit pas vider la grille entière.
      expect(gifs.map((g) => g.id), ['bon']);
    });

    test('hauteur nulle ou absente -> ratio 1, jamais de division par zéro', () {
      final gifs = gifsDepuisReponseProxy({
        'provider': 'giphy',
        'payload': {
          'data': [
            {
              'id': 'plat',
              'images': {
                'original': {
                  'url': 'https://g.test/plat.gif',
                  'width': '10',
                  'height': '0',
                },
              },
            },
          ],
        },
      });

      expect(gifs.single.aspectRatio, 1.0);
    });

    test('fournisseur inconnu -> ServerException', () {
      // Un nom que l'app ne connaît pas signifie qu'on ne sait pas quelle
      // forme lire : mieux vaut échouer que rendre une grille vide.
      expect(
        () => gifsDepuisReponseProxy({
          'provider': 'inconnu',
          'payload': {'data': []},
        }),
        throwsA(isA<ServerException>()),
      );
    });

    test('enveloppe absente -> ServerException', () {
      expect(
        () => gifsDepuisReponseProxy({'results': []}),
        throwsA(isA<ServerException>()),
      );
    });
  });
}
