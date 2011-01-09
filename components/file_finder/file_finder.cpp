/*
  OpenMW - The completely unofficial reimplementation of Morrowind

  This file is part of the OpenMW package.

  OpenMW is distributed as free software: you can redistribute it
  and/or modify it under the terms of the GNU General Public License
  version 3, as published by the Free Software Foundation.

  This program is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  version 3 along with this program. If not, see
  http://www.gnu.org/licenses/ .
 */
#include "components/file_finder/file_finder.hpp"

#include <iostream>

using namespace std;
using namespace boost::filesystem;

namespace FileFinder {

/** Search the given path and return all file paths through 'ret'. If
    recurse==true, all files in subdirectories are returned as well.
*/
void find(const path & dir_path, Inserter &ret, bool recurse)
{
    if ( !exists( dir_path ) ){
        cout << "Path " << dir_path << " not found\n";
        return;
    }

    directory_iterator end_itr; // default construction yields past-the-end
    for ( directory_iterator itr(dir_path); itr != end_itr; ++itr ) {
        if ( is_directory( *itr ) ) {
            if (recurse){
                find(*itr, ret, recurse);
            }
        }
        else
            ret.add(*itr);
    }
}

void normalize(std::string& pth) {
    for (size_t i=0; i<pth.size(); ++i) {
        if (pth[i] >= 'A' && pth[i] <= 'Z') {
            pth[i] += 'a'-'A';
        } else if (pth[i] == '\\') {
            pth[i] = '/';
        }
    }
}

FileFinder::FileFinder(const boost::filesystem::path &path, bool recurse)
{
    Inserter inserter( *this );

    // Remember the original path length, so we can cut it away from
    // the relative paths used as keys
    std::string pstring = path.file_string();
    inserter.cut = pstring.size();

    // If the path does not end in a slash, then boost will add one
    // later, which means one more character we have to remove.
    char last = pstring[pstring.size()-1];
    if (last != '\\' && last != '/')
        inserter.cut++;

    // Fill the map
    find(path, inserter, recurse);
}

const std::string& FileFinder::lookup(const std::string& file) const
{
    std::string copy = file;
    normalize(copy);
    std::map<std::string,std::string>::const_iterator it = table.find(copy);
    if( it == table.end() ){
        std::string msg = "No data file: ";
        msg += file;
        throw std::runtime_error(msg);
    }
    return it->second;
}


}
