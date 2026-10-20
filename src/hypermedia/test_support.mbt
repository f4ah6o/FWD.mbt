///|
/// Test helpers for hypermedia fixtures.

///|
pub fn read_text(path : String, label : String) -> Result[String, String] {
  let result : Result[String, @fs.IOError] = Ok(@fs.read_file_to_string(path)) catch {
    error => Err(error)
  }
  match result {
    Ok(text) => Ok(text)
    Err(err) => Err("read failed: " + label + ": " + err.to_string())
  }
}
