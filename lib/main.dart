import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Future<List<Character>> characters;
  late Database _database;

  @override
  void initState() {
    super.initState();
    characters = fetchCharacters();
    initDatabase();
  }

  Future<void> initDatabase() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'favorites_database.db'),
      onCreate: (db, version) {
        return db.execute(
          'CREATE TABLE favorites(id INTEGER PRIMARY KEY, name TEXT, image TEXT)',
        );
      },
      version: 1,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Rick and Morty Characters'),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FavoritesPage(database: _database),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder(
        future: characters,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            List<Character> charactersList = snapshot.data as List<Character>;
            return ListView.builder(
              itemCount: charactersList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(charactersList[index].name),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailPage(
                            character: charactersList[index],
                            database: _database),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  SearchPage(charactersList: characters, database: _database),
            ),
          );
        },
        child: Icon(Icons.search),
      ),
    );
  }

  Future<List<Character>> fetchCharacters() async {
    final response =
        await http.get(Uri.parse('https://rickandmortyapi.com/api/character'));
    if (response.statusCode == 200) {
      Map<String, dynamic> data = jsonDecode(response.body);
      List<dynamic> charactersList = data['results'];
      return charactersList
          .map((character) => Character.fromJson(character))
          .toList();
    } else {
      throw Exception('Failed to load characters');
    }
  }
}

class DetailPage extends StatelessWidget {
  final Character character;
  final Database database;

  DetailPage({required this.character, required this.database});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(character.name),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.network(character.image),
          Text('Name: ${character.name}'),
          Text('Species: ${character.species}'),
          Text('Gender: ${character.gender}'),
          Text('Origin: ${character.origin}'),
          Text('Location: ${character.location}'),
          IconButton(
            icon: Icon(Icons.favorite),
            onPressed: () {
              addToFavorites(context, character);
            },
          ),
        ],
      ),
    );
  }

  Future<void> addToFavorites(BuildContext context, Character character) async {
    await database.insert(
      'favorites',
      {'name': character.name, 'image': character.image},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added to favorites: ${character.name}'),
        duration: Duration(seconds: 3),
      ),
    );
  }
}

class SearchPage extends StatefulWidget {
  final Future<List<Character>> charactersList;
  final Database database;

  SearchPage({required this.charactersList, required this.database});

  @override
  _SearchPageState createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  late Future<List<Character>> searchResults;

  @override
  void initState() {
    super.initState();
    searchResults = widget.charactersList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          onChanged: (query) {
            setState(() {
              searchResults = searchCharacters(query);
            });
          },
          decoration: InputDecoration(
            hintText: 'Search characters...',
          ),
        ),
      ),
      body: FutureBuilder(
        future: searchResults,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            List<Character> charactersList = snapshot.data as List<Character>;
            return ListView.builder(
              itemCount: charactersList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(charactersList[index].name),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailPage(
                          character: charactersList[index],
                          database: widget.database,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          }
        },
      ),
    );
  }

  Future<List<Character>> searchCharacters(String query) async {
    final allCharacters = await widget.charactersList;
    return allCharacters
        .where((character) =>
            character.name.toLowerCase().contains(query.toLowerCase()))
        .toList();
  }
}

class FavoritesPage extends StatefulWidget {
  final Database database;

  FavoritesPage({required this.database});

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  late Future<List<Map<String, dynamic>>> favorites;

  @override
  void initState() {
    super.initState();
    favorites = fetchFavorites();
  }

  Future<List<Map<String, dynamic>>> fetchFavorites() async {
    return widget.database.query('favorites');
  }

  Future<void> removeFromFavorites(BuildContext context, int id) async {
    await widget.database.delete('favorites', where: 'id = ?', whereArgs: [id]);
    setState(() {
      favorites = fetchFavorites();
    });

    // Show SnackBar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed from favorites'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorite Characters'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: favorites,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CircularProgressIndicator();
          } else if (snapshot.hasError) {
            return Text('Error: ${snapshot.error}');
          } else {
            List<Map<String, dynamic>> favoritesList = snapshot.data!;
            return ListView.builder(
              itemCount: favoritesList.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(favoritesList[index]['name']),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DetailPage(
                          character: Character(
                            id: favoritesList[index]['id'],
                            name: favoritesList[index]['name'],
                            species: '',
                            gender: '',
                            origin: '',
                            location: '',
                            image: favoritesList[index]['image'],
                          ),
                          database: widget.database,
                        ),
                      ),
                    );
                  },
                  trailing: IconButton(
                    icon: Icon(Icons.delete),
                    onPressed: () {
                      removeFromFavorites(context, favoritesList[index]['id']);
                    },
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}

class Character {
  final int id;
  final String name;
  final String species;
  final String gender;
  final String origin;
  final String location;
  final String image;

  Character({
    required this.id,
    required this.name,
    required this.species,
    required this.gender,
    required this.origin,
    required this.location,
    required this.image,
  });

  factory Character.fromJson(Map<String, dynamic> json) {
    return Character(
      id: json['id'],
      name: json['name'],
      species: json['species'],
      gender: json['gender'],
      origin: json['origin']['name'],
      location: json['location']['name'],
      image: json['image'],
    );
  }
}
