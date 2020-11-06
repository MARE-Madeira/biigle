# Advanced module development

In this tutorial you will learn some advanced techniques in module development for BIIGLE, like creating new routes and views, and how to test them using the BIIGLE testing environment.

In a previous tutorial you have learned what PHP package development is all about and how to start developing your own BIIGLE module. If you haven't done the tutorial yet, <a href="/module-development/module-development">start there</a> and come back later, since we'll build upon that.


Now we would like to take our <code>quotes</code> module and add a new route as well as a new view to the BIIGLE core application. Following the name of the module, the new view should display a random quote. We'll use the existing dashboard panel to add a link to the new view (otherwise the users will be unable to reach it).


But before writing any production code, there always comes the testing. If you never heard of Test Driven Development, go <a href="https://web.archive.org/web/20190510110550/butunclebob.com/ArticleS.UncleBob.TheThreeRulesOfTdd">ask Uncle Bob</a> and come back afterwards. Having a server application with restricted access and sensitive data thoroughly tested is always essential!

##Testing

Testing our <code>quotes</code> module on its own doesn't work for us, since we need Laravel for the routes, views and controllers we intend to implement. The core application has its testing environment already set up with all functional/unit tests residing in <code>tests/php</code>. All you have to do is run <code>composer test</code> in the root directory of the BIIGLE installation and the tests run. It would be best if we were able to test our module just like it would belong to the core application and fortunately there is a very easy way to do so.

As already mentioned in the previous tutorial, we are now able to develop the module right out of the cloned repository in <code>vendor/biigle/quotes</code>. This is where we now create a new <code>tests</code> directory besides the existing <code>src</code>. Now all we have to do is to create a simple symlink from the <code>tests/php</code> directory of the core application to the new <code>tests</code> directory of our module:

```
ln -s ../../../vendor/biigle/quotes/tests/ tests/php/Modules/Quotes
```
  
Now the tests of our module are just like any other part of the core application and will be run with <code>composer test</code> as well. Let's try testing a new test! Create a new test class in <code>vendor/biigle/quotes/tests</code> called <code>QuotesServiceProviderTest.php</code> with the following content:
<pre><code>&lt;?php

namespace Biigle\Tests\Modules\Quotes;

use TestCase;
use Biigle\Modules\Quotes\QuotesServiceProvider;

class QuotesServiceProviderTest extends TestCase {

    public function testServiceProvider()
    {
        $this->assertTrue(class_exists(QuotesServiceProvider::class));
    }
}
</code></pre>

You see, the test class is located in the <code>Biigle\Tests</code> namespace and looks just like all the other test classes of the core application. You'll find lots of examples on testing there, too. For more information, see the <a href="http://laravel.com/docs/5.5/testing">Laravel</a> and <a href="https://phpunit.de/manual/current/en/appendixes.assertions.html">PHPUnit</a> documentations. But does our test even pass? Check it by running PHPUnit in the root directory of the core application:

```
$ composer testf QuotesServiceProviderTest
PHPUnit 7.5.13 by Sebastian Bergmann and contributors.

.                                                        1 / 1 (100%)

Time: 760 ms, Memory: 42.00 MB

OK (1 test, 1 assertion)
```

Great! Now on to production code.

## A new route

Usually, when creating a new view, we also need to create a new route. Routes are all possible URLs your web application can respond to; all RESTful API endpoints are routes, for example, and even the URL of this simple tutorial view is a route, too. What we would like to create is a <code>quotes</code> route, like <code>{{ url('quotes') }}</code>. Additionally, only logged in users should be allowed to visit this route.

### Adding routes with a custom module

All routes of the core application are declared in the <code>routes</code> directory. If you take a look at the files in this directory, you'll see that route definitions can get quite complex. Fortunately being able to add routes with custom modules is a great way of keeping things organized.

So just like the core application, we'll create a new <code>src/Http</code> directory for our module and add an empty <code>routes.php</code> file to it. For Laravel to load the routes declared in this file, we have to extend the <code>boot</code> method of our <code>QuotesServiceProvider</code> yet again:
<pre><code>&lt;?php

namespace Biigle\Modules\Quotes;

use Biigle\Services\Modules;
use Illuminate\Routing\Router;
use Illuminate\Support\ServiceProvider;

class QuotesServiceProvider extends ServiceProvider {

 /**
 * Bootstrap the application events.
 *
 * @param Modules $modules
 * @param  Router  $router
 * @return  void
 */
 public function boot(Modules $modules, Router $router)
 {
    $this->loadViewsFrom(__DIR__.'/resources/views', 'quotes');
    $router->group([
          'namespace' => 'Biigle\Modules\Quotes\Http\Controllers',
          'middleware' => 'web',
      ], function ($router) {
          require __DIR__.'/Http/routes.php';
      });
    $modules->register('quotes', ['viewMixins' => ['dashboardMain']]);
 }

 /**
 * Register the service provider.
 *
 * @return  void
 */
 public function register()
 {
    //
 }
}
</code></pre>

The new addition injects the <code>$router</code> object into the <code>boot</code> method. We then use this object to declare a new group of routes that will use the <code>Biigle\Modules\Quotes\Http\Controllers</code> namespace and are defined in the <code>src/Http/routes.php</code> file.

Now we can start implementing our first route.

### Implementing a new route

But first come the tests! Since it is very handy to have the tests for routes, controllers and views in one place (those three always belong together), we'll create a new test class already called <code>tests/Http/Controllers/QuotesControllerTest.php</code> looking like this:
<pre><code>&lt;?php

namespace Biigle\Tests\Modules\Quotes\Http\Controllers;

use TestCase;

class QuotesControllerTest extends TestCase {

    public function testRoute()
    {
       $this->get('quotes')->assertStatus(200);
    }
}

</code></pre>

Note how the directory structure always matches the namespace of the PHP class. With the single test function, we call the <code>quotes</code> route we intend to implement, and check if the response is HTTP <code>200</code>. Let's check what PHPunit has to say about this:

```
> composer testf QuotesControllerTest
PHPUnit 7.5.13 by Sebastian Bergmann and contributors.

F                                                                   1 / 1 (100%)

Time: 759 ms, Memory: 42.00 MB

There was 1 failure:

1) Biigle\Tests\Modules\Quotes\Http\Controllers\QuotesControllerTest::testRoute
Expected status code 200 but received 404.
Failed asserting that false is true.

/var/www/vendor/laravel/framework/src/Illuminate/Foundation/Testing/TestResponse.php:78
/var/www/vendor/biigle/quotes/tests/Http/Controllers/QuotesControllerTest.php:11
```

Of course the test fails with a <code>404</code> since we haven't implemented the route yet and it can't be found by Laravel. But that's the spirit of developing TDD-like! To create the route, populate the new <code>routes.php</code> with the following content:
<pre><code>&lt;?php

$router->get('quotes', [
 'as' => 'quotes',
 'uses' => 'QuotesController@index',
]);
</code></pre>

Here we tell Laravel that the <code>index</code> method of the <code>QuotesController</code> class of our module is responsible to handle <code>GET</code> requests to the <code>{{ url('quotes') }}</code> route. The router automatically looks for the class in the <code>Biigle\Modules\Quotes\Http\Controllers</code> namespace, since we defined it that way in the service provider. We also give the route the name <code>quotes</code> which will come in handy when we want to create links to it. Let's run the test again:

```
[...]
1) QuotesControllerTest::testRoute
Expected status code 200 but received 500.
Failed asserting that false is true.
[...]
```

Now we get a <code>500</code>, that's an improvement, isn't it? You might have already guessed why we get the internal server error here: The controller for handling the request is still missing.

## A new controller

Controllers typically reside in the <code>Http/Controllers</code> namespace of a Laravel application. We defined the <code>src</code> directory of our module to be the root of the <code>Biigle\Modules\Quotes</code> namespace so we now create the new <code>src/Http/Controllers</code> directory to reflect the <code>Biigle\Modules\Quotes\Http\Controllers</code> namespace of our new controller.

### Creating a controller

Let's create the controller by adding a new <code>QuotesController.php</code> to the <code>Controllers</code> directory, containing:
<pre><code>&lt;?php

namespace Biigle\Modules\Quotes\Http\Controllers;

use Biigle\Http\Controllers\Views\Controller;

class QuotesController extends Controller {

    /**
    * Shows the quotes page.
    *
    * @return \Illuminate\Http\Response
    */
    public function index()
    {
    }
}
</code></pre>

The controller already extends the <code>Controller</code> class of the BIIGLE core application instead of the default Laravel controller, which will come in handy in a next tutorial. Let's have a look at our test:

```
$ composer testf QuotesControllerTest
PHPUnit 7.5.13 by Sebastian Bergmann and contributors.

.                                                        1 / 1 (100%)

Time: 762 ms, Memory: 42.00 MB

OK (1 test, 1 assertion)
```

Neat! You can now call the <code>quotes</code> route in your BIIGLE application whithout causing any errors. But wait, shouldn't the route have restricted access? If the user is not logged in, they should be redirected to the login page instead of seeing the quotes. Let's adjust our test:
<pre><code>&lt;?php

namespace Biigle\Tests\Modules\Quotes\Http\Controllers;

use TestCase;
use Biigle\Tests\UserTest;

class QuotesControllerTest extends TestCase {

    public function testRoute()
    {
        $user = UserTest::create();

        // Redirect to login page.
        $this->get('quotes')->assertStatus(302);

        $this->be($user);
        $this->get('quotes')->assertStatus(200);
    }
}
</code></pre>

We first create a new test user (the <code>UserTest</code> class takes care of this), save them to the testing database and check if the route is only available if the user is authenticated. Now the test should fail again because the route is public:

```
[...]
1) QuotesControllerTest::testRoute
Expected status code 302 but received 200.
[...]
```

### Middleware

Restricting the route to authenticated users is really simple since BIIGLE has everything already implemented. User authentication in Laravel is done using <a href="http://laravel.com/docs/5.5/middleware">middleware</a>, methods that are run before or after each request and are able to intercept it when needed.

In BIIGLE, user authentication is checked by the <code>auth</code> middleware. To add the <code>auth</code> middleware to our route, we extend the route definition:

```
$router->get('quotes', [
 'middleware' => 'auth',
 'as' => 'quotes',
 'uses' => 'QuotesController@index',
]);
```

That was it. The <code>auth</code> middleware takes care of checking for authentication and redirecting to the login page if needed. Run the test and see it pass to confirm this for yourself.

## A new view

While the route and authentication works, there still is no content on our page. From the previous tutorial we already know how to implement a view, so let's create <code>src/resources/views/index.blade.php</code>:
<pre><code>&lt;blockquote&gt;
    @{{ Illuminate\Foundation\Inspiring::quote() }}
&lt;/blockquote&gt;
</code></pre>

Now all we have to do is to tell the <code>index</code> method of our <code>QuotesController</code> to use this view as response of a request:

```
public function index()
{
    return view('quotes::index');
}
```

Here, the <code>quotes::</code> view namespace is used which we defined in the <code>boot</code> method of our service provider in the previous tutorial. If we didn't use it, Laravel would look for the <code>index</code> view of the core application. Now you can call the route and see the quote.

Pretty ugly, isn't it? The view doesn't look like the other BIIGLE views at all. It displays only the code we defined in the view template and nothing else. This is where view inheritance comes in.

### Inheriting views

The BIIGLE core application has an <code>app</code> view template containing all the scaffolding of a HTML page and loading the default assets. This <code>app</code> template is what makes all BIIGLE views look alike.
The Blade templating engine allows for view inheritance so you can create new views, building upon existing ones. When inheriting a view, you need to specify view <em>sections</em>, defining which part of the new view should be inserted into which part of the parent view. Let's see this in action by applying it to the <code>index.blade.php</code> view of our module:
<pre><code>&#64;extends('app')
&#64;section('title', 'Inspiring quotes')
    &#64;section('content')
    &lt;div class="container"&gt;
     &lt;div class="col-sm-8 col-sm-offset-2 col-lg-6 col-lg-offset-3"&gt;
        &lt;blockquote&gt;
           @{{ Illuminate\Foundation\Inspiring::quote() }}
        &lt;/blockquote&gt;
     &lt;/div&gt;
&lt;/div&gt;
&#64;endsection
</code></pre>

Here we tell the templating engine that our view should extend the <code>app</code> view, inheriting all its content. The <code>app</code> view has two sections we can use, <code>title</code> and <code>content</code>. The <code>title</code> section is the content of the title tag in the HTML header. The <code>content</code> section is the "body" of the BIIGLE view. Since styling the body of the page is entirely up to the child view, we have to use the Bootstrap grid to get adequate spacing.

Take a look at the page again. Now we are talking!

To finish up, we quickly add a link to the new route to the previously developed view mixin of the dashboard. Open the <code>dashboardMain</code> view and edit the panel heading:
<pre><code>&lt;div class="panel-heading"&gt;
    &lt;a href="@{{ route('quotes') }}"&gt;&lt;h3 class="panel-title"&gt;Inspiring Quote&lt;/h3&gt;&lt;/a&gt;
&lt;/div&gt;
</code></pre>

The <code>route</code> helper function is an easy way to link to routes with a name. Even if the URL of the route changes, you don't have to change any code in the views.

## Conclusion

That's it! Now you have learned how to create new routes, controllers and views, and how to test them. This is everything you need to develop complex custom modules where all the content is rendered by the server.

But there is still one step left for you to master module development: Custom assets. Besides using custom CSS to style the content beyond Bootstrap's capabilities, you need to be able to use custom JavaScript for interactive client side applications as well. In a next tutorial, we'll discuss how to include and publish custom assets and how to use the already provided functionality of the BIIGLE core client side application.
