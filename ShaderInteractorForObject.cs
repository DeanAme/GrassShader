using UnityEngine;
//This is another script that is attached to the interactive object and interacts with the grass.
public class ShaderInteractorForObject : MonoBehaviour
{
    // Update is called once per frame
    void Update()
    {
        Shader.SetGlobalVector("_PositionMoving", transform.position);
    }
}
