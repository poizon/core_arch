### Installing ###

* cd core/
* cpanm --installdeps .
* cp config.yml-dist config.yml
* mysql -u user db < sql/init.sql
* plackup -R lib/,views/,config.yml,languages/ bin/app.pl
* Go to http://127.0.0.1:5000 or use /etc/hosts

### MySQL ###

* INSERT INTO users (email, password) VALUES ('test@test.ru', MD5('test'));
* INSERT INTO sites (user_id, template) VALUES ( last_insert_id(), 'mimity');
* INSERT INTO domains (site_id, ascii, unicode) VALUES ( last_insert_id(), 'test.ru', 'test.ru');
* UPDATE sites SET default_domain = last_insert_id();

### Froala WYSIWYG ###

* After updating froala_editor.min.js to new version find there code
function h(){return a.$box?(a.$box.append
* insert "return false" in h() function to skip license check
function h(){return false;return a.$box?(a.$box.append
