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
#ifndef FILE_FINDER_MAIN_H
#define FILE_FINDER_MAIN_H

#include <boost/filesystem.hpp>
#include <map>

namespace FileFinder
{

/** Normalize a relative path by replacing \ with / and capital letters with
 * small letters. */
void normalize(std::string& pth);

/** Represents a mapping from relative data paths to absolute paths, with
 * case and path-separator insensitive matches (windows/unix compatibility).
 *****************************************************************************/
class FileFinder
{
    // Map of standardized relative paths (lower-case, / instead of \ ) to absolute paths
    std::map<std::string, std::string> table;
    friend class Inserter;
    
public:
    /** Constructor.
     * 
     * @param path Absolute path to a data directory
     * @param recurse If true, also look in subfolders for data files
     */
    FileFinder(const boost::filesystem::path &path, bool recurse=true);
    
    //NOTE: has() and lookup() have to create a copy of input path
    
    /** Does this file exist? */
    bool has(const std::string& file) const
    {
        std::string copy = file;
        normalize(copy);
        return table.find(copy) != table.end();
    }

    /** Find the full path from a relative path.
     * 
     * @throws runtime_error when path not found */
    const std::string& lookup(const std::string& file) const;
};

struct Inserter
{
    FileFinder& owner;
    int cut;

    Inserter( FileFinder& ff ) : owner(ff) {}

    void add(const boost::filesystem::path &pth)
    {
        std::string file = pth.file_string();     // full path
        std::string key = file.substr(cut);  // relative path
        normalize( key );
        owner.table[key] = file;
    }
};

}
#endif
