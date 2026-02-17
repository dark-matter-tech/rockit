package com.darkmatter.rockit

import com.intellij.openapi.editor.colors.TextAttributesKey
import com.intellij.openapi.fileTypes.SyntaxHighlighter
import com.intellij.openapi.options.colors.AttributesDescriptor
import com.intellij.openapi.options.colors.ColorDescriptor
import com.intellij.openapi.options.colors.ColorSettingsPage
import javax.swing.Icon

class RockitColorSettingsPage : ColorSettingsPage {

    companion object {
        private val DESCRIPTORS = arrayOf(
            AttributesDescriptor("Keywords//Declaration keyword", RockitSyntaxHighlighter.KEYWORD),
            AttributesDescriptor("Keywords//Control flow keyword", RockitSyntaxHighlighter.CONTROL_KEYWORD),
            AttributesDescriptor("Keywords//Rockit keyword (view, actor, suspend...)", RockitSyntaxHighlighter.ROCKIT_KEYWORD),
            AttributesDescriptor("Keywords//Boolean literal (true, false)", RockitSyntaxHighlighter.BOOLEAN_LITERAL),
            AttributesDescriptor("Identifiers//Boolean identifier (is..., has..., can...)", RockitSyntaxHighlighter.BOOLEAN_IDENTIFIER),
            AttributesDescriptor("Identifiers//Function call", RockitSyntaxHighlighter.FUNCTION_CALL),
            AttributesDescriptor("Keywords//Null literal", RockitSyntaxHighlighter.NULL_LITERAL),
            AttributesDescriptor("Operators//Optional operator (?, ?., ?:)", RockitSyntaxHighlighter.OPTIONAL_OPERATOR),
            AttributesDescriptor("Operators//Force unwrap (!!)", RockitSyntaxHighlighter.FORCE_UNWRAP),
            AttributesDescriptor("Types//Built-in type", RockitSyntaxHighlighter.BUILTIN_TYPE),
            AttributesDescriptor("Functions//Built-in function", RockitSyntaxHighlighter.BUILTIN_FUNCTION),
            AttributesDescriptor("Strings//String literal", RockitSyntaxHighlighter.STRING),
            AttributesDescriptor("Strings//Escape sequence", RockitSyntaxHighlighter.STRING_ESCAPE),
            AttributesDescriptor("Strings//String interpolation", RockitSyntaxHighlighter.STRING_INTERPOLATION),
            AttributesDescriptor("Number", RockitSyntaxHighlighter.NUMBER),
            AttributesDescriptor("Comments//Line comment", RockitSyntaxHighlighter.LINE_COMMENT),
            AttributesDescriptor("Comments//Block comment", RockitSyntaxHighlighter.BLOCK_COMMENT),
            AttributesDescriptor("Operators//Operator", RockitSyntaxHighlighter.OPERATOR),
            AttributesDescriptor("Braces and Operators//Parentheses", RockitSyntaxHighlighter.PARENTHESES),
            AttributesDescriptor("Braces and Operators//Braces", RockitSyntaxHighlighter.BRACES),
            AttributesDescriptor("Braces and Operators//Brackets", RockitSyntaxHighlighter.BRACKETS),
            AttributesDescriptor("Braces and Operators//Dot", RockitSyntaxHighlighter.DOT),
            AttributesDescriptor("Braces and Operators//Comma", RockitSyntaxHighlighter.COMMA),
            AttributesDescriptor("Braces and Operators//Semicolon", RockitSyntaxHighlighter.SEMICOLON),
            AttributesDescriptor("Annotation", RockitSyntaxHighlighter.ANNOTATION),
            AttributesDescriptor("Identifier", RockitSyntaxHighlighter.IDENTIFIER),
            AttributesDescriptor("Bad character", RockitSyntaxHighlighter.BAD_CHAR),
        )
    }

    override fun getIcon(): Icon = RockitIcons.FILE

    override fun getHighlighter(): SyntaxHighlighter = RockitSyntaxHighlighter()

    override fun getDemoText(): String = """
// Rockit Language — syntax highlighting demo
package com.example.app

import rockit.ui.*
import rockit.net.HttpClient

/* This is a block comment.
   /* It supports nesting! */
   Still inside the outer comment. */

@Capability("network")
@Capability("storage")

// --- Data types and sealed classes ---
data class User(val name: String, val age: Int, val email: String?)

sealed class Shape {
    data class Circle(val radius: Double)
    data class Rect(val width: Double, val height: Double)
    object Empty
}

fun area(shape: Shape): Double = when (shape) {
    is Shape.Circle -> shape.radius * shape.radius * 3.14159
    is Shape.Rect   -> shape.width * shape.height
    is Shape.Empty  -> 0.0
}

// --- Enum with methods ---
enum class Color {
    RED, GREEN, BLUE;

    fun hex(): String = when (this) {
        RED   -> "#FF0000"
        GREEN -> "#00FF00"
        BLUE  -> "#0000FF"
    }
}

// --- Null safety and operators ---
fun greet(name: String?) {
    val displayName: String = name ?: "World"
    val len: Int = name?.length ?: 0
    println("Hello, ${'$'}displayName! (length=${'$'}{len})")

    if (name != null) {
        val upper = name!!
        println("Shouting: ${'$'}{upper}")
    }
}

// --- Collections and lambdas ---
fun demo() {
    val numbers: List<Int> = listOf(1, 2, 3, 4, 5)
    val hex = 0xFF
    val binary = 0b1010
    val big = 1_000_000
    val pi = 3.14159e0

    for (n in numbers) {
        if (n > 3) break
        println(n)
    }

    val evens = numbers.filter { it % 2 == 0 }
    val pairs: Map<String, Int> = mapOf("a" to 1, "b" to 2)
    val result: Result<String> = try {
        Result.success("ok")
    } catch (e: Exception) {
        Result.failure(e)
    }
}

// --- Rockit UI ---
view Greeting(val name: String) {
    Text("Hello, ${'$'}name!")
}

view Counter(val initial: Int = 0) {
    @State var count = initial
    Column {
        Text("Count: ${'$'}count")
        Button("Increment") { count += 1 }
    }
}

// --- Concurrency ---
actor BankAccount {
    private var balance: Double = 0.0

    suspend fun deposit(amount: Double) {
        balance += amount
    }

    suspend fun getBalance(): Double = balance
}

suspend fun fetchData(client: HttpClient) {
    concurrent {
        val users = await client.get("/users")
        val posts = await client.get("/posts")
    }
    println("Done!")
}

// --- Navigation ---
navigation AppRouter {
    route("/") { Greeting("Rockit") }
    route("/counter") { Counter(0) }
}

// --- Theme and style ---
theme AppTheme {
    val primary = Color.BLUE
    val background = "#1E1E2E"
}

// --- Multi-line strings ---
val query = ${"\"\"\""}
    SELECT *
    FROM users
    WHERE age > 18
    ORDER BY name
${"\"\"\""}

fun main() {
    greet("Rockit")
    greet(null)
    demo()
    println(area(Shape.Circle(5.0)))
}
""".trimIndent()

    override fun getAdditionalHighlightingTagToDescriptorMap(): Map<String, TextAttributesKey>? = null

    override fun getAttributeDescriptors(): Array<AttributesDescriptor> = DESCRIPTORS

    override fun getColorDescriptors(): Array<ColorDescriptor> = ColorDescriptor.EMPTY_ARRAY

    override fun getDisplayName(): String = "Rockit"
}
