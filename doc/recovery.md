
# Récupération de données depuis un backup

Hello,
ce document se veut être un guide pour récupérer des données en cas de perte.
Aujourd’hui, nous ne supportons que le re-import des **dossiers**

## Dossiers

### exporter les dossiers du backup
Se connecter a la base qui contient les données perdu
```bash
$ DB_DATABASE=db_name DB_HOST=db_host ruby bin/rails c
```
Le process se veut simple, instancier un objet qui permet de sérializer des dossiers (sous forme de Marshall.dump).
```ruby
exporter = Recovery::Exporter.new(dossier_ids:)
exporter.dump
# le fichier se retrouve Recovery::Exporter::FILE_PATH
```

### importer les dossiers sur la prod
Se connecter à la base de prod
```bash
ruby bin/rails console
```
Le process se veut simple, instancier un objet qui permet de déserializer les dossiers exportés et les ré-importer dans la base.
```ruby
importer = Recovery::Importer.new(file_path: 'lib/data/export.dump')
importer.load
```


